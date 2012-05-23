# Copyright (c) 2009-2012 VMware, Inc.

# This relies on having the following instance variables in a host class:
# @dev_builds_dir, @final_builds_dir, @blobstore,
# @name, @version, @tarball_path, @final, @artefact_type

module Bosh::Cli
  module PackagingHelper
    include Bosh::Cli::VersionCalc

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

    def older_version?
      if @tarball_generated
        false
      elsif @used_final_version
        version_cmp(@version, @final_index.latest_version) < 0
      else
        version_cmp(@version, @dev_index.latest_version) < 0
      end
    end

    def notes
      notes = []

      if @will_be_promoted
        new_final_version = @final_index.latest_version.to_i + 1
        notes << "new final version #{new_final_version}"
      elsif new_version?
        notes << "new version"
      end

      notes << "older than latest" if older_version?
      notes
    end

    def build
      with_indent("  ") do
        use_final_version || use_dev_version || generate_tarball
      end
      upload_tarball(@tarball_path) if final? && !dry_run?
      @will_be_promoted = true if final? && dry_run? && @used_dev_version
    end

    def use_final_version
      say("Final version:", " ")

      item = @final_index[fingerprint]

      if item.nil?
        say("NOT FOUND".red)
        return nil
      end

      blobstore_id = item["blobstore_id"]
      version      = item["version"]

      if blobstore_id.nil?
        say("No blobstore id".red)
        return nil
      end

      filename = @final_index.filename(version)
      need_fetch = true

      if File.exists?(filename)
        say("FOUND LOCAL".green)
        if file_checksum(filename) == item["sha1"]
          @tarball_path = filename
          need_fetch = false
        else
          say("LOCAL CHECKSUM MISMATCH".red)
          need_fetch = true
        end
      end

      if need_fetch
        say("Downloading `#{name} (#{version})'...".green)
        payload = @blobstore.get(blobstore_id)
        if Digest::SHA1.hexdigest(payload) == item["sha1"]
          @tarball_path = @final_index.add_version(fingerprint, item, payload)
        else
          err("`#{name}' (#{version}) is corrupted in blobstore " +
                  "(id=#{blobstore_id}), " +
                  "please remove it manually and re-generate the final release")
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
      say("Dev version:", "   ")
      item = @dev_index[fingerprint]

      if item.nil?
        say("NOT FOUND".red)
        return nil
      end

      version = item["version"]
      filename = @dev_index.filename(version)

      if File.exists?(filename)
        say("FOUND LOCAL".green)
      else
        say("TARBALL MISSING".red)
        return nil
      end

      if file_checksum(filename) == item["sha1"]
        @tarball_path = filename
        @version = version
        @used_dev_version = true
      else
        say("`#{name} (#{version})' tarball corrupted".red)
        return nil
      end
    end

    def generate_tarball
      if final?
        err_message = "No matching build found for " +
            "`#{@name}' #{@artefact_type}.\n" +
            "Please consider creating a dev release first.\n" +
            "The fingerprint is `#{fingerprint}'."
        err(err_message)
      end

      current_final = @final_index.latest_version.to_i
      new_minor = minor_version(@dev_index.latest_version(current_final)) + 1

      version = "#{current_final}.#{new_minor}-dev"
      tmp_file = Tempfile.new(name)

      say("Generating...")

      copy_files

      in_build_dir do
        tar_out = `tar -chzf #{tmp_file.path} . 2>&1`
        unless $?.exitstatus == 0
          raise PackagingError, "Cannot create tarball: #{tar_out}"
        end
      end

      payload = tmp_file.read

      item = {
        "version" => version
      }

      unless dry_run?
        @dev_index.add_version(fingerprint, item, payload)
        @tarball_path = @dev_index.filename(version)
      end

      @version = version
      @tarball_generated = true
      say("Generated version #{version}".green)
      true
    end

    def upload_tarball(path)
      item = @final_index[fingerprint]

      say("Uploading final version #{version}...")

      if !item.nil?
        version = item["version"]
        say("This package has already been uploaded")
        return
      end

      version = @final_index.latest_version.to_i + 1
      payload = File.read(path)

      blobstore_id = @blobstore.create(payload)

      item = {
        "blobstore_id" => blobstore_id,
        "version" => version
      }

      say("Uploaded, blobstore id #{blobstore_id}")
      @final_index.add_version(fingerprint, item, payload)
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
              "cannot read checksum for not yet generated package/job"
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
        "40755"
      elsif File.executable?(path)
        "100755"
      else
        "100644"
      end
    end
  end
end

