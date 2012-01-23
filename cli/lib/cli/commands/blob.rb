module Bosh::Cli::Command
  class Blob < Base

    BLOB_DIR = "blob"
    BLOB_INDEX_FILE = "blob_index.yml"

    def upload_blob(*params)
      check_working_dir
      force = !params.delete("--force").nil?

      blobs = []
      params.each do |param|
        blobs << get_blob_name(param)
      end

      total = blobs.size
      count = 0
      blob_index = parse_index_file

      blobs.each do |blob_name|
        count += 1
        blob_file = File.join(BLOB_DIR, blob_name)
        blob_sha = Digest::SHA1.file(blob_file).hexdigest 

        if !blob_index[blob_name].nil? && !force
          # we already have this binary on record
          if blob_index[blob_name]['sha'] == blob_sha
            say "[#{count}/#{total}] Skipping #{blob_name}".green
            next
          end
          # local copy is different from the remote copy
          confirm = ask("\nBlob #{blob_name} changed, do you want to update the binary [Yn]: ")
          if !confirm.empty? && confirm =~ /no?$/i
            say "[#{count}/#{total}] Skipping #{blob_name}".green
            next
          end
        end

        #TODO: We could use the sha and try to avoid uploading duplicated objects.
        say "[#{count}/#{total}] Uploading #{blob_name}".green
        blob_id = blobstore_client.create(File.open(blob_file, "r"))
        blob_index[blob_name] = {'object_id' => blob_id, 'sha' => blob_sha}
      end

      # update the index file
      index_file = Tempfile.new("tmp_blob_index")
      index_file.write(YAML.dump(blob_index))
      index_file.close
      FileUtils.mv(index_file.path, File.join(work_dir, BLOB_INDEX_FILE))
    end

    def sync_blob(*options)
      check_working_dir
      force = options.include?("--force")

      blob_index = parse_index_file
      total = blob_index.size
      count = 0

      blob_index.each_pair do |name, blob_info|
        count += 1
        blob_file = File.join(work_dir, BLOB_DIR, name)

        # check if we have conflicting blobs
        if File.file?(blob_file) && !force
          blob_sha = Digest::SHA1.file(blob_file).hexdigest
          if blob_sha == blob_info['sha']
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

    def blob_status
      check_working_dir
      untracked = []
      modified = []
      tracked= []
      unsynced = []

      local_blobs = {}
      Dir.chdir(BLOB_DIR) do 
        Dir.glob("**/*").select { |entry| File.file?(entry) }.each do |file|
          local_blobs[file] = Digest::SHA1.file(file).hexdigest
        end
      end
      remote_blobs = parse_index_file

      local_blobs.each do |blob_name, blob_sha|
        if remote_blobs[blob_name].nil?
          untracked << blob_name
        elsif blob_sha != remote_blobs[blob_name]['sha']
          modified << blob_name
        else
          tracked << blob_name
        end
      end

      remote_blobs.each_key do |blob_name|
        unsynced << blob_name if local_blobs[blob_name].nil?
      end

      if modified.size > 0
        say "\nModified blobs ('bosh upload blob' to update): ".green
        modified.each { |blob| say blob }
      end

      if untracked.size > 0
        say "\nNew blobs ('bosh upload blob' to add): ".green
        untracked.each { |blob| say blob }
      end

      if unsynced.size > 0
        say "\nMissing blobs ('bosh sync blob' to fetch) : ".green
        unsynced.each { |blob| say blob }
      end

      if modified.size + untracked.size + unsynced.size == 0
        say "\nRelease blob in sync".green
      end
    end

    private

    def check_working_dir
      check_if_release_dir
      if !File.directory?(BLOB_DIR)
        err "Can't find blob directory (#{BLOB_DIR}). Try updating the release"
      end

      if !File.file?(BLOB_INDEX_FILE)
        err "Can't find #{BLOB_INDEX_FILE}. Try updating the release"
      end
    end

    # parse blob_index file
    def parse_index_file
      index_file = File.join(work_dir, BLOB_INDEX_FILE)
      blob = YAML.load_file(index_file)
      blob = {} if !blob
      blob
    end

    # sanity check the input file and returns the blob_name
    def get_blob_name(file)
      err "Invalid file #{file}" unless File.file?(file)
      blob_dir = File.join(work_dir, "#{BLOB_DIR}/")
      file_path = ""
      Dir.chdir(File.dirname(file)) do
        file_path = File.join(Dir.pwd, File.basename(file))
      end

      if file_path[0, blob_dir.length] != blob_dir
        err "#{file_path} is NOT under #{blob_dir}"
      end
      file_path[blob_dir.length, file_path.length]
    end

    # download the blob (blob_info) into dst_file
    def fetch_blob(dst_file, blob_info)
      oid = blob_info['object_id']

      # creating directory
      FileUtils.mkdir_p(File.dirname(dst_file))

      # fetch the blob
      new_blob = Tempfile.new(dst_file)
      blobstore_client.get(oid, new_blob)
      new_blob.close
      FileUtils.mv(new_blob.path, dst_file)

      # Paranoia...
      if blob_info['sha'] != Digest::SHA1.file(dst_file).hexdigest
        say "FATAL-ERROR: inconsistent sha".red
      end
    end

    def blobstore_client
      return @blobstore if @blobstore
      @blobstore = init_blobstore(Bosh::Cli::Release.final(work_dir).blobstore_options)
    end
  end
end
