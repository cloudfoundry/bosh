module Bosh::Director::Jobs
  module Helpers
    class PackageDeleter
      def initialize(compiled_package_deleter, blobstore, logger)
        @compiled_package_deleter = compiled_package_deleter
        @blobstore = blobstore
        @logger = logger
      end

      def delete(package, force)
        errors = []
        compiled_packages = package.compiled_packages

        @logger.info("Deleting package #{package.name}/#{package.version}")

        compiled_packages.each do |compiled_package|
          begin
            @compiled_package_deleter.delete(compiled_package, {'force' => force})
          rescue Exception => e
            errors << e
          end
        end

        if delete_blobstore_id(package.blobstore_id, errors, force)
          package.remove_all_release_versions
          package.destroy
        end

        errors
      end

      private

      def delete_blobstore_id(blobstore_id, errors, force)
        return true if blobstore_id.nil?

        begin
          @blobstore.delete(blobstore_id)
          return true
        rescue Exception => e
          @logger.warn("Could not delete from blobstore: #{e}\n " + e.backtrace.join("\n"))
          errors << e
        end

        force
      end
    end
  end
end
