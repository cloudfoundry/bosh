module Bosh::Director
  class BlobUtil
    # @param [String] path Path to a file to be uploaded
    # @return [String] Created blob id
    def self.create_blob(path)
      File.open(path) { |f| blobstore.create(f) }
    end

    def self.copy_blob(blobstore_id)
      # Create a copy of the given blob
      Dir.mktmpdir do |path|
        temp_path = File.join(path, "blob")
        File.open(temp_path, 'w') do |file|
          blobstore.get(blobstore_id, file)
        end
        File.open(temp_path, 'r') do |file|
          blobstore_id = blobstore.create(file)
        end
      end
      blobstore_id
    end

    def self.delete_blob(blobstore_id)
      blobstore.delete(blobstore_id)
    end
    
    def self.save_to_global_cache(compiled_package, cache_key)
      global_cache_filename = [compiled_package.package.name, cache_key].join('-')
      Dir.mktmpdir do |path|
        temp_path = File.join(path, 'blob')
        File.open(temp_path, 'wb') do |file|
          blobstore.get(compiled_package.blobstore_id, file)
        end

        File.open(temp_path) do |file|
          compiled_package_cache_blobstore.create(file, global_cache_filename)
        end
      end
    end

    def self.exists_in_global_cache?(package, cache_key)
      global_cache_filename = [package.name, cache_key].join('-')
      compiled_package_cache_blobstore.exists?(global_cache_filename)
    end

    def self.fetch_from_global_cache(package, stemcell, cache_key, dependency_key)
      global_cache_filename = [package.name, cache_key].join('-')

      blobstore_id = nil
      compiled_package_sha1 = nil

      Dir.mktmpdir do |path|
        blob_path = File.join(path, 'blob')
        begin
          File.open(blob_path, 'wb') do |file|
            compiled_package_cache_blobstore.get(global_cache_filename, file)
          end
        rescue Bosh::Blobstore::NotFound => e
          # if the object is not found in the cache, we ignore it and return nil
          return nil
        end

        File.open(blob_path) do |file|
          blobstore_id = blobstore.create(file)
          compiled_package_sha1 = ::Digest::SHA1.file(blob_path).hexdigest
        end
      end

      Models::CompiledPackage.create do |p|
        p.package = package
        p.stemcell_os = stemcell.os
        p.stemcell_version = stemcell.version
        p.sha1 = compiled_package_sha1
        p.build = Models::CompiledPackage.generate_build_number(package, stemcell.os, stemcell.version)
        p.blobstore_id = blobstore_id
        p.dependency_key = dependency_key
      end
    end

    private

    def self.blobstore
      App.instance.blobstores.blobstore
    end

    def self.compiled_package_cache_blobstore
      Config.compiled_package_cache_blobstore
    end
  end
end
