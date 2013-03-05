# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class BlobUtil
    extend ::Bosh::Director::VersionCalc

    # @param [String] path Path to a file to be uploaded
    # @return [String] Created blob id
    def self.create_blob(path)
      File.open(path) { |f| Bosh::Director::Config.blobstore.create(f) }
    end

    def self.copy_blob(blobstore_id)
      # Create a copy of the given blob
      Dir.mktmpdir do |path|
        temp_path = File.join(path, "blob")
        File.open(temp_path, "w") do |file|
          Bosh::Director::Config.blobstore.get(blobstore_id, file)
        end
        File.open(temp_path, "r") do |file|
          blobstore_id = Bosh::Director::Config.blobstore.create(file)
        end
      end
      blobstore_id
    end

    def self.save_to_global_cache(compiled_package, cache_key)
      global_cache_filename = [compiled_package.package.name, cache_key].join("-")
      Dir.mktmpdir do |path|
        temp_path = File.join(path, "blob")
        File.open(temp_path, "wb") do |file|
          Bosh::Director::Config.blobstore.get(compiled_package.blobstore_id, file)
        end
        Bosh::Director::Config.compiled_package_cache.create(
          key:  global_cache_filename,
          body: File.open(temp_path, "rb")
        )
      end
    end

    def self.exists_in_global_cache?(package, cache_key)
      global_cache_filename = [package.name, cache_key].join("-")
      head = Bosh::Director::Config.compiled_package_cache.head(global_cache_filename)
      ! head.nil?
    end

    def self.fetch_from_global_cache(package, stemcell, cache_key, dependency_key)
      global_cache_filename = [package.name, cache_key].join("-")
      blobstore_file = Bosh::Director::Config.compiled_package_cache.get(global_cache_filename)

      return nil unless blobstore_file

      blobstore_id = nil
      compiled_package_sha1 = nil
      Dir.mktmpdir do |path|
        temp_path = File.join(path, "blob")
        File.open(temp_path, "wb") do |local_file|
          local_file.write(blobstore_file.body)
        end
        File.open(temp_path, "rb") do |file|
          blobstore_id = Bosh::Director::Config.blobstore.create(file)
        end
        compiled_package_sha1 = Digest::SHA1.file(temp_path).hexdigest
      end

      Models::CompiledPackage.create do |p|
        p.package = package
        p.stemcell = stemcell
        p.sha1 = compiled_package_sha1
        p.build = Models::CompiledPackage.generate_build_number(package, stemcell)
        p.blobstore_id = blobstore_id
        p.dependency_key = dependency_key
      end
    end
  end
end
