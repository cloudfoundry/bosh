module Bosh::Director::Jobs
  module Helpers
    class CompiledPackageDeleter
      def initialize(blobstore, logger)
        @blobstore = blobstore
        @logger = logger
      end

      def delete(compiled_package, force = false)
        package = compiled_package.package
        @logger.info('Deleting compiled package: ' +
          "#{package.name}/#{package.version}" +
          "for #{compiled_package.stemcell_os}/#{compiled_package.stemcell_version}")

        begin
          @blobstore.delete(compiled_package.blobstore_id)
        rescue Exception => e
          @logger.debug("Failed to delete blob #{compiled_package.blobstore_id}: #{e.message}")
          raise e unless force
        end

        compiled_package.destroy
      end
    end
  end
end
