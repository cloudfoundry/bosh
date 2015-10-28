module Bosh::Director::Jobs
  module Helpers
    class CompiledPackageDeleter
      def initialize(blobstore, logger, event_log)
        @blobstore = blobstore
        @logger = logger
        @event_log = event_log
      end

      def delete(compiled_package, options = {})
        package = compiled_package.package
        stemcell = compiled_package.stemcell
        @logger.info('Deleting compiled package: ' +
            "#{package.name}/#{package.version}" +
            "for #{stemcell.name}/#{stemcell.version}")

        begin
          @blobstore.delete(compiled_package.blobstore_id)
        rescue Exception => e
          message = "Could not delete from blobstore: #{e}\n " + e.backtrace.join("\n")
          raise Bosh::Director::CompiledPackageDeletionFailed, message unless options['force']
          @logger.warn(message)
        end

        compiled_package.destroy
      end
    end
  end
end
