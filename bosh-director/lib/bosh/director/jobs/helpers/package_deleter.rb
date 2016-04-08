module Bosh::Director::Jobs
  module Helpers
    class PackageDeleter
      def initialize(compiled_package_deleter, blob_deleter, logger)
        @compiled_package_deleter = compiled_package_deleter
        @blob_deleter = blob_deleter
        @logger = logger
      end

      def delete(package, force)
        errors = []
        @logger.info("Deleting package #{package.name}/#{package.version}")

        package.compiled_packages.each do |compiled_package|
          errors += @compiled_package_deleter.delete(compiled_package, {'force' => force})
        end

        delete_successful = true

        if package.blobstore_id
          delete_successful = @blob_deleter.delete(package.blobstore_id, errors, force)
        end

        if delete_successful
          package.remove_all_release_versions
          package.destroy
        end

        errors
      end
    end
  end
end
