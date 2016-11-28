module Bosh::Director::Jobs
  module Helpers
    class PackageDeleter
      def initialize(compiled_package_deleter, blobstore, logger)
        @compiled_package_deleter = compiled_package_deleter
        @blobstore = blobstore
        @logger = logger
      end

      def delete(package, force)
        @logger.info("Deleting package #{package.name}/#{package.version}")

        package.compiled_packages.each do |compiled_package|
          @compiled_package_deleter.delete(compiled_package, force)
        end

        if package.blobstore_id
          begin
            @blobstore.delete(package.blobstore_id)
          rescue Exception => e
            raise e unless force
          end
        end

        package.remove_all_release_versions
        package.destroy
      end
    end
  end
end
