# This relies on having the following instance variables in a host class:
# @dev_builds_dir, @final_builds_dir, @blobstore,
# @name, @version, @tarball_path, @final, @artefact_type

module Bosh::Cli
  module PackagingHelper
    attr_accessor :dry_run

    def init_indices
      @dev_index   = VersionsIndex.new(@dev_builds_dir)
      @final_index = VersionsIndex.new(@final_builds_dir)
    end

    def final?
      @final
    end

    def dry_run?
      @dry_run
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
      with_indent('  ') do
        use_final_version || use_dev_version || generate_tarball
      end
      upload_tarball(@tarball_path) if final? && !dry_run?
      @will_be_promoted = true if final? && dry_run? && @used_dev_version
    end

    def use_final_version
      say('Final version:', ' ')

      item = @final_index[fingerprint]

      if item.nil?
        say('NOT FOUND'.make_red)
        return nil
      end

      blobstore_id = item['blobstore_id']
      version      = fingerprint

      if blobstore_id.nil?
        say('No blobstore id'.make_red)
        return nil
      end

      filename = @final_index.filename(version)
      need_fetch = true

      if File.exists?(filename)
        say('FOUND LOCAL'.make_green)
        if file_checksum(filename) == item['sha1']
          @tarball_path = filename
          need_fetch = false
        else
          say('LOCAL CHECKSUM MISMATCH'.make_red)
          need_fetch = true
        end
      end

      if need_fetch
        say("Downloading `#{name} (#{version})'...".make_green)
        tmp_file = File.open(File.join(Dir.mktmpdir, name), 'w')
        @blobstore.get(blobstore_id, tmp_file)
        tmp_file.close
        if Digest::SHA1.file(tmp_file.path).hexdigest == item['sha1']
          @tarball_path = @final_index.add_version(fingerprint,
                                                   item,
                                                   tmp_file.path)
        else
          err("`#{name}' (#{version}) is corrupted in blobstore " +
                  "(id=#{blobstore_id}), " +
            'please remove it manually and re-generate the final release')
        end
      end

      @version = version
      @used_final_version = true
      true
    rescue Bosh::Blobstore::NotFound => e
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

      version = fingerprint
      filename = @dev_index.filename(version)

      if File.exists?(filename)
        say('FOUND LOCAL'.make_green)
      else
        say('TARBALL MISSING'.make_red)
        return nil
      end

      if file_checksum(filename) == item['sha1']
        @tarball_path = filename
        @version = version
        @used_dev_version = true
      else
        say("`#{name} (#{version})' tarball corrupted".make_red)
        return nil
      end
    end

    def generate_tarball
      version = fingerprint
      tmp_file = Tempfile.new(name)

      say('Generating...')

      copy_files

      in_build_dir do
        tar_out = `tar -chzf #{tmp_file.path} . 2>&1`
        unless $?.exitstatus == 0
          raise PackagingError, "Cannot create tarball: #{tar_out}"
        end
      end

      item = {
        'version' => version
      }

      if final?
        @final_index.add_version(fingerprint, item, tmp_file.path)
        @tarball_path = @final_index.filename(version)
      elsif dry_run?
      else
        @dev_index.add_version(fingerprint, item, tmp_file.path)
        @tarball_path = @dev_index.filename(version)
      end

      @version = version
      @tarball_generated = true
      say("Generated version #{version}".make_green)
      true
    end

    def upload_tarball(path)
      item = @final_index[fingerprint]

      say("Uploading final version #{version}...")

      if item
        say('This package has already been uploaded')
        return
      end

      version = fingerprint

      blobstore_id = nil
      File.open(path, 'r') do |f|
        blobstore_id = @blobstore.create(f)
      end

      item = {
        'blobstore_id' => blobstore_id,
        'version' => version
      }

      say("Uploaded, blobstore id #{blobstore_id}")
      @final_index.add_version(fingerprint, item, path)
      @tarball_path = @final_index.filename(version)
      @version = version
      @promoted = true
      true
    rescue Bosh::Blobstore::BlobstoreError => e
      raise BlobstoreError, "Blobstore error: #{e}"
    end

    def file_checksum(path)
      Digest::SHA1.file(path).hexdigest
    end

    def checksum
      if @tarball_path && File.exists?(@tarball_path)
        file_checksum(@tarball_path)
      else
        raise RuntimeError,
          'cannot read checksum for not yet generated package/job'
      end
    end

    # Git doesn't really track file permissions, it just looks at executable
    # bit and uses 0755 if it's set or 0644 if not. We have to mimic that
    # behavior in the fingerprint calculation to avoid the situation where
    # seemingly clean working copy would trigger new fingerprints for
    # artifacts with changed permissions. Also we don't want current
    # fingerprints to change, hence the exact values below.
    def tracked_permissions(path)
      if File.directory?(path)
        '40755'
      elsif File.executable?(path)
        '100755'
      else
        '100644'
      end
    end
  end
end

