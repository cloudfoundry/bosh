module Bosh::Cli
  class CachingVersionsIndex

    attr_reader :versions_index

    def initialize(versions_index, name_prefix=nil)
      @versions_index = versions_index
      @name_prefix = name_prefix
    end

    def [](key)
      @versions_index[key]
    end

    def add_version(new_key, new_build, src_payload_path)
      version = @versions_index.add_version(new_key, new_build)

      destination = filename(version)
      unless File.exist?(src_payload_path)
        raise "Trying to copy payload `#{src_payload_path}' for version `#{new_build['version']}'"
      end
      FileUtils.cp(src_payload_path, destination, :preserve => true)

      new_build['sha1'] = Digest::SHA1.file(src_payload_path).hexdigest
      @versions_index.update_version(new_key, new_build)

      File.expand_path(destination)
    end

    def set_blobstore_id(key, blobstore_id)
      build = @versions_index[key]
      unless build
        raise "Trying to set blobstore_id `#{blobstore_id}' " +
          "on missing version record `#{key}' in index `#{@versions_index.index_file}'"
      end
      if build['blobstore_id']
        raise "Trying to replace blobstore_id `#{build['blobstore_id']}' " +
          "with `#{blobstore_id}' for version `#{build['version']}' in index `#{@versions_index.index_file}'"
      end
      build['blobstore_id'] = blobstore_id
      @versions_index.update_version(key, build)
    end

    def version_exists?(version)
      File.exists?(filename(version))
    end

    def filename(version)
      name = @name_prefix.blank? ? "#{version}.tgz" : "#{@name_prefix}-#{version}.tgz"
      File.join(@versions_index.storage_dir, name)
    end

    def find_by_checksum(checksum)
      @versions_index.select{ |_, build| build['sha1'] == checksum }.values.first
    end
  end
end
