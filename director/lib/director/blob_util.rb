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

    def self.save_to_global_cache(compiled_package)
      global_cache_filename = [compiled_package.package.name, compiled_package_cache_key(compiled_package.package, compiled_package.stemcell)].join("-")
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

    def self.exists_in_global_cache?(package, stemcell)
      global_cache_filename = [package.name, compiled_package_cache_key(package, stemcell)].join("-")
      head = Bosh::Director::Config.global_blobstore.head(global_cache_filename)
      ! head.nil?
    end

    def self.compiled_package_cache_key(package, stemcell)
      dependency_fingerprints = []
      package.dependency_set.sort.each do |package_name|
        all_matches = Bosh::Director::Models::Package.filter(name: package_name)
        dependent_model = nil
        all_matches.each do |match|
          if dependent_model.nil? || version_less(dependent_model.version, match.version)
            dependent_model = match
          end
        end
        dependency_fingerprints << dependent_model.fingerprint
      end
      hash_input = ([package.fingerprint, stemcell.sha1]+dependency_fingerprints).join("")
      Digest::SHA1.hexdigest(hash_input)
    end

  end
end
