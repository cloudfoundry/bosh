# This relies on having the following instance variables in a host class:
# @dev_builds_dir, @final_builds_dir, @blobstore,
# @name, @version, @tarball_path, @final

module Bosh::Cli
  class ArchiveBuilder
    attr_accessor :tarball_path, :resource
    attr_reader :options

    def initialize(resource, archive_dir, blobstore, options = {})
      @resource = resource
      @archive_dir = archive_dir
      @blobstore = blobstore
      @options = options
    end

    def final?
      @final ||= !!options[:final]
    end

    def dry_run?
      @dry_run || !!options[:dry_run]
    end

    def new_version?
      @tarball_generated || @promoted || @will_be_promoted
    end

    def notes
      notes = []

      if @will_be_promoted
        new_final_version = @version
        notes << "new final version #{new_final_version}"
      elsif new_version?
        notes << 'new version'
      end

      notes
    end

    def build
      @dev_builds_dir = File.join(@archive_dir, ".dev_builds", "#{resource.artifact_type}s", resource.name)
      @final_builds_dir = File.join(@archive_dir, ".final_builds", "#{resource.artifact_type}s", resource.name)

      FileUtils.mkdir_p(@dev_builds_dir)
      FileUtils.mkdir_p(@final_builds_dir)
      init_indices

      with_indent('  ') do
        use_final_version || use_dev_version || generate_tarball
      end

      # TEMP: package specific properties are set back on the package object
      # for backwards compatibility while refactoring archive building, etc.
      resource.fingerprint = fingerprint
      resource.version = resource_version
      resource.checksum = checksum unless dry_run?
      resource.notes = notes
      resource.new_version = new_version?
      resource.tarball_path = @tarball_path

      upload_tarball(@tarball_path) if final? && !dry_run?
      @will_be_promoted = true if final? && dry_run? && @used_dev_version
      self
    end

    def checksum
      if @tarball_path && File.exists?(@tarball_path)
        file_checksum(@tarball_path)
      else
        raise RuntimeError, "cannot read checksum for not yet generated #{@resource.artifact_type}"
      end
    end

    def fingerprint
      @fingerprint ||= make_fingerprint
    end

    def resource_version
      @version
    end

    private

    def additional_fingerprints
      @resource.dependencies.sort
    end

    def copy_files
      @resource.files.each do |src, dest|
        dest_path = Pathname(staging_dir).join(dest)
        if File.directory?(src)
          FileUtils.mkdir_p(dest_path)
        else
          FileUtils.mkdir_p(dest_path.parent)
          FileUtils.cp(src, dest_path, :preserve => true)
        end
      end
    end

    def digest_file(filename)
      File.file?(filename) ? Digest::SHA1.file(filename).hexdigest : ''
    end

    def init_indices
      @dev_index   = Versions::VersionsIndex.new(@dev_builds_dir)
      @dev_storage = Versions::LocalVersionStorage.new(@dev_builds_dir)

      @final_index = Versions::VersionsIndex.new(@final_builds_dir)
      @final_storage = Versions::LocalVersionStorage.new(@final_builds_dir)

      @final_resolver = Versions::VersionFileResolver.new(@final_storage, @blobstore)
    end

    def make_fingerprint
      versioning_scheme = 2
      contents = "v#{versioning_scheme}"

      @resource.files.each do |filename, name|
        contents << @resource.format_fingerprint(digest_file(filename), filename, name, file_mode(filename))
      end

      contents << additional_fingerprints.join(",")
      Digest::SHA1.hexdigest(contents)
    end

    def use_final_version
      say('Final version:', ' ')

      item = @final_index[fingerprint]

      if item.nil?
        say('NOT FOUND'.make_red)
        return nil
      end

      blobstore_id = item['blobstore_id']
      version      = item['version'] || fingerprint
      sha1         = item['sha1']

      if blobstore_id.nil?
        say('No blobstore id'.make_red)
        return nil
      end

      desc = "#{@resource.name} (#{version})"

      @tarball_path = @final_resolver.find_file(blobstore_id, sha1, version, "package #{desc}")

      @version = version
      @used_final_version = true
      true
    rescue Bosh::Blobstore::NotFound
      raise BlobstoreError, "Final version of `#{name}' not found in blobstore"
    rescue Bosh::Blobstore::BlobstoreError => e
      raise BlobstoreError, "Blobstore error: #{e}"
    end

    def use_dev_version
      say('Dev version:', '   ')
      item = @dev_index[fingerprint]

      if item.nil?
        say('NOT FOUND'.make_red)
        return nil
      end

      version = @dev_index['version'] || fingerprint

      if !@dev_storage.has_file?(version)
        say('TARBALL MISSING'.make_red)
        return nil
      end

      say('FOUND LOCAL'.make_green)
      @tarball_path = @dev_storage.get_file(version)

      if file_checksum(@tarball_path) != item['sha1']
        say("`#{name} (#{version})' tarball corrupted".make_red)
        return nil
      end

      if final? && !dry_run?
        # copy from dev index/storage to final index/storage
        @final_index.add_version(fingerprint, item)
        @tarball_path = @final_storage.put_file(version, @tarball_path)
        item['sha1'] = Digest::SHA1.file(@tarball_path).hexdigest
        @final_index.update_version(fingerprint, item)
      end

      @version = version
      @used_dev_version = true
    end

    def generate_tarball
      version = fingerprint
      tmp_file = Tempfile.new(@resource.name)

      say('Generating...')

      copy_files
      @resource.pre_package(staging_dir)

      in_staging_dir do
        tar_out = `tar -chzf #{tmp_file.path} . 2>&1`
        unless $?.exitstatus == 0
          raise PackagingError, "Cannot create tarball: #{tar_out}"
        end
      end

      item = {
        'version' => version
      }

      if final?
        # add version (with its validation) before adding sha1
        @final_index.add_version(fingerprint, item)
        @tarball_path = @final_storage.put_file(fingerprint, tmp_file.path)
        item['sha1'] = file_checksum(@tarball_path)
        @final_index.update_version(fingerprint, item)
      elsif dry_run?
      else
        # add version (with its validation) before adding sha1
        @dev_index.add_version(fingerprint, item)
        @tarball_path = @dev_storage.put_file(fingerprint, tmp_file.path)
        item['sha1'] = file_checksum(@tarball_path)
        @dev_index.update_version(fingerprint, item)
      end

      @version = version
      @tarball_generated = true
      say("Generated version #{version}".make_green)
      true
    end

    def upload_tarball(path)
      item = @final_index[fingerprint]

      unless item
        say("Failed to find entry `#{fingerprint}' in index, check local storage")
        return
      end

      if item['blobstore_id']
        return
      end

      say("Uploading final version `#{resource_version}'...")

      blobstore_id = nil
      File.open(path, 'r') do |f|
        blobstore_id = @blobstore.create(f)
      end

      say("Uploaded, blobstore id `#{blobstore_id}'")
      item['blobstore_id'] = blobstore_id
      @final_index.update_version(fingerprint, item)
      @promoted = true
      true
    rescue Bosh::Blobstore::BlobstoreError => e
      raise BlobstoreError, "Blobstore error: #{e}"
    end

    def file_checksum(path)
      Digest::SHA1.file(path).hexdigest
    end

    # Git doesn't really track file permissions, it just looks at executable
    # bit and uses 0755 if it's set or 0644 if not. We have to mimic that
    # behavior in the fingerprint calculation to avoid the situation where
    # seemingly clean working copy would trigger new fingerprints for
    # artifacts with changed permissions. Also we don't want current
    # fingerprints to change, hence the exact values below.
    def file_mode(path)
      if File.directory?(path)
        '40755'
      elsif File.executable?(path)
        '100755'
      else
        '100644'
      end
    end

    def staging_dir
      @staging_dir ||= Dir.mktmpdir
    end

    def in_staging_dir
      Dir.chdir(staging_dir) { yield }
    end
  end
end
