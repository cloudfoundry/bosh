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
        Bosh::Director::Config.global_blobstore.create(
          key:  global_cache_filename,
          body: File.open(temp_path, "rb")
        )
      end
    end

    def self.exists_in_global_cache?(package, cache_key)
      global_cache_filename = [package.name, cache_key].join("-")
      head = Bosh::Director::Config.global_blobstore.head(global_cache_filename)
      ! head.nil?
    end
  end
end
