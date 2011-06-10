require "blobstore_client"

# This relies on having the following instance variables in a host class:
# @dev_builds_dir, @final_builds_dir, @blobstore, @name, @version, @tarball_path

module Bosh
  module Cli
    module PackagingHelper

      def init_indices
        @dev_index   = VersionsIndex.new(@dev_builds_dir)
        @final_index = VersionsIndex.new(@final_builds_dir)
      end

      def use_final_version
        say "Final version:", " "

        item = @final_index[fingerprint]

        if item.nil?
          say "NOT FOUND".red
          return nil
        end

        blobstore_id = item["blobstore_id"]
        version      = item["version"]

        if blobstore_id.nil?
          say "No blobstore id".red
          return nil
        end

        filename = @final_index.filename(version)
        need_fetch = true

        if File.exists?(filename)
          say "FOUND LOCAL".green
          if file_checksum(filename) == item["sha1"]
            @tarball_path = filename
            need_fetch = false
          else
            say "LOCAL CHECKSUM MISMATCH".red
            need_fetch = true
          end
        end

        if need_fetch
          say "Downloading `#{name} (#{version})' (#{blobstore_id})".green
          payload = @blobstore.get(blobstore_id)
          if Digest::SHA1.hexdigest(payload) == item["sha1"]
            @tarball_path = @final_index.add_version(fingerprint, item, payload)
          else
            err("`#{name}' (#{version}) is corrupted in blobstore (id=#{blobstore_id}), please remove it manually and re-generate the final release")
          end
        end

        @version = version
        true
      rescue Bosh::Blobstore::NotFound => e
        raise BlobstoreError, "Final version of `#{name}' not found in blobstore"
      rescue Bosh::Blobstore::BlobstoreError => e
        raise BlobstoreError, "Blobstore error: #{e}"
      end

      def use_dev_version
        say "Dev version:", "   "
        item = @dev_index[fingerprint]

        if item.nil?
          say "NOT FOUND".red
          return nil
        end

        version  = item["version"]
        filename = @dev_index.filename(version)

        if File.exists?(filename)
          say "FOUND LOCAL".green
        else
          say "TARBALL MISSING".red
          return nil
        end

        if file_checksum(filename) == item["sha1"]
          @tarball_path = filename
          @version      = version
        else
          say "`#{name} (#{version})' tarball corrupted".red
          return nil
        end
      end

      def generate_tarball
        current_final = @final_index.latest_version.to_i

        if @dev_index.latest_version.to_s =~ /^(\d+)\.(\d+)/
          major, minor = $1.to_i, $2.to_i
          minor = major == current_final ? minor + 1 : 1
          major = current_final
        else
          major, minor = current_final, 1
        end

        version  = "#{major}.#{minor}-dev"
        tmp_file = Tempfile.new(name)

        say "Generating..."

        copy_files

        in_build_dir do
          tar_out = `tar -chzf #{tmp_file.path} . 2>&1`
          raise PackagingError, "Cannot create tarball: #{tar_out}" unless $?.exitstatus == 0
        end

        payload = tmp_file.read

        item = {
          "version" => version
        }

        @dev_index.add_version(fingerprint, item, payload)
        @tarball_path   = @dev_index.filename(version)
        @version        = version

        say "Generated version #{version}".green
        true
      end

      def upload_tarball(path)
        item = @final_index[fingerprint]

        say "Uploading final version #{version}..."

        if !item.nil?
          version = item["version"]
          say "This package has already been uploaded"
          return
        end

        version = @final_index.latest_version.to_i + 1
        payload = File.read(path)

        blobstore_id = @blobstore.create(payload)

        item = {
          "blobstore_id" => blobstore_id,
          "version"      => version
        }

        say "Uploaded, blobstore id #{blobstore_id}"
        @final_index.add_version(fingerprint, item, payload)
        @tarball_path = @final_index.filename(version)
        @version      = version
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
          raise RuntimeError, "cannot read checksum for not yet generated package/job"
        end
      end

    end
  end
end
