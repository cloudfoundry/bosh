# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class BlobUtil

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

    def self.save_to_global_cache(package_name, package_fingerprint, stemcell_sha1, blob_id)
      Dir.mktmpdir do |path|
        temp_path = File.join(path, "blob")
        File.open(temp_path, "wb") do |file|
          Bosh::Director::Config.blobstore.get(blob_id, file)
        end
        Bosh::Director::Config.global_blobstore.create(
          key:  [package_name, package_fingerprint, stemcell_sha1].join("-"),
          body: File.open(temp_path, "rb")
        )
      end
    end

    def self.exists_in_global_cache?(package_name, package_fingerprint, stemcell_sha1)
      head = Bosh::Director::Config.global_blobstore.head([package_name, package_fingerprint, stemcell_sha1].join("-"))
      ! head.nil?
    end
  end
end
