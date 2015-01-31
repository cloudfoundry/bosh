module Bosh::Cli
  class ArchiveBuilder
    attr_reader :options

    def initialize(archive_dir, blobstore, options = {})
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

    def build(resource)
      artifact = BuildArtifact.new(resource)

      init_directories(resource)
      init_indices

      with_indent('  ') do
        artifact.tarball_path = locate_tarball(resource, artifact) || generate_tarball(resource, artifact)
      end

      artifact.notes = notes
      artifact.new_version = new_version?

      upload_tarball(artifact) if final? && !dry_run?
      @will_be_promoted = true if final? && dry_run? && @used_dev_version

      artifact
    end

    private

    def copy_files(resource)
      resource.files.each do |src, dest|
        dest_path = Pathname(staging_dir).join(dest)
        if File.directory?(src)
          FileUtils.mkdir_p(dest_path)
        else
          FileUtils.mkdir_p(dest_path.parent)
          FileUtils.cp(src, dest_path, :preserve => true)
        end
      end
    end

    def init_directories(resource)
      @dev_builds_dir = File.join(@archive_dir, ".dev_builds", "#{resource.artifact_type}s", resource.name)
      @final_builds_dir = File.join(@archive_dir, ".final_builds", "#{resource.artifact_type}s", resource.name)

      FileUtils.mkdir_p(@dev_builds_dir)
      FileUtils.mkdir_p(@final_builds_dir)
    end

    def init_indices
      @dev_index   = Versions::VersionsIndex.new(@dev_builds_dir)
      @dev_storage = Versions::LocalVersionStorage.new(@dev_builds_dir)

      @final_index = Versions::VersionsIndex.new(@final_builds_dir)
      @final_storage = Versions::LocalVersionStorage.new(@final_builds_dir)

      @final_resolver = Versions::VersionFileResolver.new(@final_storage, @blobstore)
    end

    def locate_tarball(resource, artifact)
      use_final_version(resource, artifact) || use_dev_version(resource, artifact)
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

    def use_final_version(resource, artifact)
      say('Final version:', ' ')

      item = @final_index[artifact.fingerprint]

      if item.nil?
        say('NOT FOUND'.make_red)
        return nil
      end

      blobstore_id = item['blobstore_id']
      version      = item['version'] || artifact.fingerprint
      sha1         = item['sha1']

      if blobstore_id.nil?
        say('No blobstore id'.make_red)
        return nil
      end

      desc = "#{resource.name} (#{version})"

      tarball_path = @final_resolver.find_file(blobstore_id, sha1, version, "package #{desc}")

      @version = version
      @used_final_version = true
      tarball_path
    rescue Bosh::Blobstore::NotFound
      raise BlobstoreError, "Final version of '#{name}' not found in blobstore"
    rescue Bosh::Blobstore::BlobstoreError => e
      raise BlobstoreError, "Blobstore error: #{e}"
    end

    def use_dev_version(resource, artifact)
      say('Dev version:', '   ')
      item = @dev_index[artifact.fingerprint]

      if item.nil?
        say('NOT FOUND'.make_red)
        return nil
      end

      version = @dev_index['version'] || artifact.fingerprint

      if !@dev_storage.has_file?(version)
        say('TARBALL MISSING'.make_red)
        return nil
      end

      say('FOUND LOCAL'.make_green)
      tarball_path = @dev_storage.get_file(version)

      # TODO: move everything below here, as it's not actually about finding and using.
      if file_checksum(tarball_path) != item['sha1']
        say("'#{name} (#{version})' tarball corrupted".make_red)
        return nil
      end

      if final? && !dry_run?
        # copy from dev index/storage to final index/storage
        @final_index.add_version(artifact.fingerprint, item)
        tarball_path = @final_storage.put_file(version, tarball_path)
        item['sha1'] = Digest::SHA1.file(tarball_path).hexdigest
        @final_index.update_version(artifact.fingerprint, item)
      end

      @version = version
      @used_dev_version = true
      tarball_path
    end

    def generate_tarball(resource, artifact)
      version = artifact.fingerprint
      tmp_file = Tempfile.new(artifact.name)

      say('Generating...')

      copy_files(resource)
      resource.pre_package(staging_dir)

      in_staging_dir do
        tar_out = `tar -chzf #{tmp_file.path} . 2>&1`
        unless $?.exitstatus == 0
          raise PackagingError, "Cannot create tarball: #{tar_out}"
        end
      end

      # TODO: move everything below here, as it's not actually about generating a tarball.
      item = {
        'version' => version
      }

      if final?
        # add version (with its validation) before adding sha1
        @final_index.add_version(artifact.fingerprint, item)
        tarball_path = @final_storage.put_file(artifact.fingerprint, tmp_file.path)
        item['sha1'] = file_checksum(tarball_path)
        @final_index.update_version(artifact.fingerprint, item)
      elsif dry_run?
      else
        # add version (with its validation) before adding sha1
        @dev_index.add_version(artifact.fingerprint, item)
        tarball_path = @dev_storage.put_file(artifact.fingerprint, tmp_file.path)
        item['sha1'] = file_checksum(tarball_path)
        @dev_index.update_version(artifact.fingerprint, item)
      end

      @version = version
      @tarball_generated = true
      say("Generated version #{version}".make_green)

      tarball_path
    end

    # TODO: move out of builder
    def upload_tarball(artifact)
      item = @final_index[artifact.fingerprint]

      unless item
        say("Failed to find entry '#{artifact.fingerprint}' in index, check local storage")
        return
      end

      if item['blobstore_id']
        return
      end

      say("Uploading final version '#{artifact.version}'...")

      blobstore_id = nil
      File.open(artifact.tarball_path, 'r') do |f|
        blobstore_id = @blobstore.create(f)
      end

      say("Uploaded, blobstore id '#{blobstore_id}'")
      item['blobstore_id'] = blobstore_id
      @final_index.update_version(artifact.fingerprint, item)
      @promoted = true
      true
    rescue Bosh::Blobstore::BlobstoreError => e
      raise BlobstoreError, "Blobstore error: #{e}"
    end

    def file_checksum(path)
      Digest::SHA1.file(path).hexdigest
    end

    def staging_dir
      @staging_dir ||= Dir.mktmpdir
    end

    def in_staging_dir
      Dir.chdir(staging_dir) { yield }
    end
  end
end
