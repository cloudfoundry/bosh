# Copyright (c) 2009-2012 VMware, Inc.
autoload :Logging, 'logging'

module Bosh::Cli
  # In order to avoid storing large objects in git repo,
  # release might save them in the blobstore instead.
  # BlobManager encapsulates most of the blob operations.
  class BlobManager
    DEFAULT_INDEX_NAME = "blobs.yml"

    attr_reader :new_blobs, :updated_blobs

    # @param [Bosh::Cli::Release] release BOSH Release object
    def initialize(release, max_parallel_downloads, progress_renderer)
      @progress_renderer = progress_renderer
      max_parallel_downloads = 1 if max_parallel_downloads.nil? || max_parallel_downloads < 1
      @max_parallel_downloads = max_parallel_downloads

      @release = release
      @index_file = File.join(@release.dir, "config", DEFAULT_INDEX_NAME)

      legacy_index_file = File.join(@release.dir, "blob_index.yml")

      if File.exists?(legacy_index_file)
        if File.exists?(@index_file)
          err("Found both new and legacy blob index, please fix it")
        end
        FileUtils.mv(legacy_index_file, @index_file)
      end

      if File.file?(@index_file)
        @index = load_yaml_file(@index_file)
      else
        @index = {}
      end

      @src_dir = File.join(@release.dir, "src")
      unless File.directory?(@src_dir)
        err("`src' directory is missing")
      end

      @storage_dir = File.join(@release.dir, ".blobs")
      unless File.directory?(@storage_dir)
        FileUtils.mkdir(@storage_dir)
      end

      @blobs_dir = File.join(@release.dir, "blobs")
      unless File.directory?(@blobs_dir)
        FileUtils.mkdir(@blobs_dir)
      end

      @blobstore = @release.blobstore

      @new_blobs = []
      @updated_blobs = []
    end

    # Returns a list of blobs that need to be uploaded
    # @return [Array]
    def blobs_to_upload
      @new_blobs + @updated_blobs
    end

    # Returns whether blobs directory is dirty
    # @return Boolean
    def dirty?
      @new_blobs.size > 0 || @updated_blobs.size > 0
    end

    # Prints out blobs status
    # @return [void]
    def print_status
      total_file_size = @index.inject(0) do |total, (_, entry)|
        total += entry["size"].to_i
        total
      end

      say("Total: #{@index.size}, #{pretty_size(total_file_size)}")
      process_blobs_directory

      unless dirty?
        say("No blobs to upload".make_green)
        return
      end

      nl
      say("You have some blobs that need to be uploaded:")
      @new_blobs.each do |blob|
        size = File.size(File.join(@blobs_dir, blob))
        say("%s\t%s\t%s" % ["new".make_green, blob, pretty_size(size)])
      end

      @updated_blobs.each do |blob|
        size = File.size(File.join(@blobs_dir, blob))
        say("%s\t%s\t%s" % ["new version".make_yellow, blob, pretty_size(size)])
      end

      nl
      say("When ready please run `#{"bosh upload blobs".make_green}'")
    end

    # Registers a file as BOSH blob
    # @param [String] local_path Local file path
    # @param [String] blob_path Blob path relative to blobs directory
    # @return [void]
    def add_blob(local_path, blob_path)
      unless File.exists?(local_path)
        err("File `#{local_path}' not found")
      end

      if File.directory?(local_path)
        err("`#{local_path}' is a directory")
      end

      if blob_path[0..0] == "/"
        err("Blob path should be a relative path")
      end

      if blob_path[0..5] == "blobs/"
        err("Blob path should not start with `blobs/'")
      end

      blob_dst = File.join(@blobs_dir, blob_path)

      if File.directory?(blob_dst)
        err("`#{blob_dst}' is a directory, please pick a different path")
      end

      update = false
      if File.exists?(blob_dst)
        if file_checksum(blob_dst) == file_checksum(local_path)
          err("Already tracking the same version of `#{blob_path}'")
        end
        update = true
        FileUtils.rm(blob_dst)
      end

      FileUtils.mkdir_p(File.dirname(blob_dst))
      FileUtils.cp(local_path, blob_dst, :preserve => true)
      FileUtils.chmod(0644, blob_dst)
      if update
        say("Updated #{blob_path.make_yellow}")
      else
        say("Added #{blob_path.make_yellow}")
      end

      say("When you are done testing the new blob, please run\n" +
          "`#{"bosh upload blobs".make_green}' and commit changes.")
    end

    # Synchronizes the contents of blobs directory with blobs index.
    # @return [void]
    def sync
      say("Syncing blobs...")
      remove_symlinks
      process_blobs_directory
      process_index
    end

    # Processes all files in blobs directory and only leaves non-symlinks.
    # Marks blobs as dirty if there are any non-symlink files.
    # @return [void]
    def process_blobs_directory
      @updated_blobs = []
      @new_blobs = []

      Dir[File.join(@blobs_dir, "**", "*")].each do |file|
        next if File.directory?(file) || File.symlink?(file)
        # We don't care about symlinks because they represent blobs
        # that are already tracked.
        # Regular files are more interesting: it's either a new version
        # of an existing blob or a completely new blob.
        path = strip_blobs_dir(file)

        if File.exists?(File.join(@src_dir, path))
          err("File `#{path}' is in both `blobs' and `src' directory.\n" +
              "Please fix release repo before proceeding")
        end

        if @index.has_key?(path)
          if file_checksum(file) == @index[path]["sha"]
            # Already have exactly the same file in the index,
            # no need to keep it around. Also handles the migration
            # scenario for people with old blobs checked out.
            local_path = File.join(@storage_dir, @index[path]["sha"])
            if File.exists?(local_path)
              FileUtils.rm_rf(file)
            else
              FileUtils.mv(file, local_path)
            end
            install_blob(local_path, path, @index[path]["sha"])
          else
            @updated_blobs << path
          end
        else
          @new_blobs << path
        end
      end
    end

    # Removes all symlinks from blobs directory
    # @return [void]
    def remove_symlinks
      Dir[File.join(@blobs_dir, "**", "*")].each do |file|
        FileUtils.rm_rf(file) if File.symlink?(file)
      end
    end

    # Processes blobs index, fetches any missing or mismatched blobs,
    # establishes symlinks in blobs directory to any files present in index.
    # @return [void]
    def process_index
      missing_blobs = []
      @index.each_pair do |path, entry|
        if File.exists?(File.join(@src_dir, path))
          err("File `#{path}' is in both blob index and src directory.\n" +
              "Please fix release repo before proceeding")
        end

        local_path = File.join(@storage_dir, entry["sha"])
        need_download = true

        if File.exists?(local_path)
          checksum = file_checksum(local_path)
          if checksum == entry["sha"]
            need_download = false
          else
            @progress_renderer.error(path, "checksum mismatch, re-downloading...")
          end
        end

        if need_download
          missing_blobs << [path, entry["sha"]]
        else
          install_blob(local_path, path, entry["sha"])
        end
      end

      Bosh::ThreadPool.new(:max_threads => @max_parallel_downloads, :logger => Logging::Logger.new(nil)).wrap do |pool|
        missing_blobs.each do |path, sha|
          pool.process do
            local_path = download_blob(path)
            install_blob(local_path, path, sha)
          end
        end
      end
    end

    # Uploads blob to a blobstore, updates blobs index.
    # @param [String] path Blob path relative to blobs dir
    def upload_blob(path)
      if @blobstore.nil?
        err("Failed to upload blobs: blobstore not configured")
      end

      blob_path = File.join(@blobs_dir, path)

      unless File.exists?(blob_path)
        err("Cannot upload blob, local file `#{blob_path}' doesn't exist")
      end

      if File.symlink?(blob_path)
        err("`#{blob_path}' is a symlink")
      end

      checksum = file_checksum(blob_path)

      @progress_renderer.start(path, "uploading...")
      object_id = @blobstore.create(File.open(blob_path, "r"))
      @progress_renderer.finish(path, "uploaded")

      @index[path] = {
        "object_id" => object_id,
        "sha" => checksum,
        "size" => File.size(blob_path)
      }

      update_index
      install_blob(blob_path, path, checksum)
      object_id
    end

    # Downloads blob from a blobstore
    # @param [String] path Downloaded blob file path
    def download_blob(path)
      if @blobstore.nil?
        err("Failed to download blobs: blobstore not configured")
      end

      unless @index.has_key?(path)
        err("Unknown blob path `#{path}'")
      end

      blob = @index[path]
      size = blob["size"].to_i
      blob_path = path.gsub(File::SEPARATOR, '-')
      tmp_file = File.open(File.join(Dir.mktmpdir, blob_path), "w")

      download_label = "downloading"
      if size > 0
        download_label += " " + pretty_size(size)
      end

      @progress_renderer.start(path, "#{download_label}")
      progress_bar = Thread.new do
        loop do
          break unless size > 0
          if File.exists?(tmp_file.path)
            pct = 100 * File.size(tmp_file.path).to_f / size
            @progress_renderer.progress(path, "#{download_label}", pct.to_i)
          end
          sleep(0.2)
        end
      end

      @blobstore.get(blob["object_id"], tmp_file, sha1: blob["sha"])
      tmp_file.close
      progress_bar.kill
      @progress_renderer.progress(path, "#{download_label}", 100)
      @progress_renderer.finish(path, "downloaded")

      tmp_file.path
    end

    private

    # @param [String] src Path to a file containing the blob
    # @param [String] dst Resulting blob path relative to blobs dir
    # @param [String] checksum Blob checksum
    def install_blob(src, dst, checksum)
      store_path = File.join(@storage_dir, checksum)
      symlink_path = File.join(@blobs_dir, dst)

      FileUtils.chmod(0644, src)

      unless File.exists?(store_path) && realpath(src) == realpath(store_path)
        # Move blob to a storage dir if it's not there yet
        FileUtils.mv(src, store_path)
      end

      unless File.exists?(symlink_path) && !File.symlink?(symlink_path)
        FileUtils.mkdir_p(File.dirname(symlink_path))
        FileUtils.rm_rf(symlink_path)
        FileUtils.ln_s(store_path, symlink_path)
      end
    end

    # Returns blob path relative to blobs dir, fails if blob is not in blobs
    # dir.
    # @param [String] path Absolute or relative blob path
    def strip_blobs_dir(path)
      blob_path = realpath(path)
      blobs_dir = realpath(@blobs_dir)

      if blob_path[0..blobs_dir.size] == blobs_dir + "/"
        blob_path[blobs_dir.size+1..-1]
      else
        err("File `#{blob_path}' is not under `blobs' directory")
      end
    end

    # Updates blobs index
    def update_index
      yaml = Psych.dump(@index).gsub(/\s*$/, "")

      index_file = Tempfile.new("blob_index")
      index_file.puts(yaml)
      index_file.close

      FileUtils.mv(index_file.path, @index_file)
    end

    # Returns file SHA1 checksum
    # @param [String] path File path
    def file_checksum(path)
      Digest::SHA1.file(path).hexdigest
    end

    # Returns real file path (resolves symlinks)
    # @param [String] path File path
    def realpath(path)
      Pathname.new(path).realpath.to_s
    end
  end
end

