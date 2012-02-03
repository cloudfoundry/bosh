module Bosh::Cli::Command
  class Blob < Base

    def upload_blob(*params)
      check_if_blobs_supported
      force = !params.delete("--force").nil?

      blobs = params.map{ |param| get_blob_name(param) }
      total = blobs.size
      blob_index = get_blobs_index

      blobs.each_with_index do |blob_name, idx|
        count = idx + 1
        blob_file = File.join(BLOBS_DIR, blob_name)
        blob_sha = Digest::SHA1.file(blob_file).hexdigest

        if blob_index[blob_name] && !force
          # we already have this binary on record
          if blob_index[blob_name]["sha"] == blob_sha
            say "[#{count}/#{total}] Skipping #{blob_name}".green
            next
          end
          # local copy is different from the remote copy
          confirm = ask("\nBlob #{blob_name} changed, do you want to update the binary [yN]: ")
          if confirm.empty? || !(confirm =~ /y(es)?$/i)
            say "[#{count}/#{total}] Skipping #{blob_name}".green
            next
          end
        end

        #TODO: We could use the sha and try to avoid uploading duplicated objects.
        say "[#{count}/#{total}] Uploading #{blob_name}".green
        blob_id = blobstore.create(File.open(blob_file, "r"))
        blob_index[blob_name] = {"object_id" => blob_id, "sha" => blob_sha}
      end

      # update the index file
      index_file = Tempfile.new("tmp_blob_index")
      index_file.write(YAML.dump(blob_index))
      index_file.close
      FileUtils.mv(index_file.path, File.join(work_dir, BLOBS_INDEX_FILE))
    end

    def sync_blobs(*options)
      check_if_blobs_supported
      force = options.include?("--force")

      blob_index = get_blobs_index
      total = blob_index.size
      count = 0

      blob_index.each_pair do |name, blob_info|
        count += 1
        blob_file = File.join(work_dir, BLOBS_DIR, name)

        # check if we have conflicting blobs
        if File.file?(blob_file) && !force
          blob_sha = Digest::SHA1.file(blob_file).hexdigest
          if blob_sha == blob_info["sha"]
            say "[#{count}/#{total}] Skipping blob #{name}".green
            next
          end

          confirm = ask("\nLocal blob (#{name}) conflicts with remote object, overwrite local copy? [yN]: ")
          if confirm.empty? || !(confirm =~ /y(es)?$/i)
            say "[#{count}/#{total}] Skipping blob #{name}".green
            next
          end
        end
        say "[#{count}/#{total}] Updating #{blob_file}".green
        fetch_blob(blob_file, blob_info)
      end
    end

    def blobs_info
      blob_status(true)
    end

    private

    # sanity check the input file and returns the blob_name
    def get_blob_name(file)
      err "Invalid file #{file}" unless File.file?(file)
      blobs_dir = File.join(work_dir, "#{BLOBS_DIR}/")
      file_path = File.expand_path(file)

      if file_path[0..blobs_dir.length - 1] != blobs_dir
        err "#{file_path} is NOT under #{blobs_dir}"
      end
      file_path[blobs_dir.length..file_path.length]
    end

    # download the blob (blob_info) into dst_file
    def fetch_blob(dst_file, blob_info)
      object_id = blob_info["object_id"]

      # fetch the blob
      new_blob = Tempfile.new("new_blob_file")
      blobstore.get(object_id, new_blob)
      new_blob.close

      # Paranoia...
      if blob_info["sha"] != Digest::SHA1.file(new_blob.path).hexdigest
        err "Fatal error: Inconsistent checksum for object #{blob_info["object_id"]}"
      end

      FileUtils.mkdir_p(File.dirname(dst_file))
      FileUtils.mv(new_blob.path, dst_file)
    end
  end
end
