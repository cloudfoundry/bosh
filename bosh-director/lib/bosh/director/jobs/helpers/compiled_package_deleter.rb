module Bosh::Director::Jobs
  module Helpers
    class CompiledPackageDeleter
      def initialize(blob_deleter, logger)
        @blob_deleter = blob_deleter
        @logger = logger
      end

      def delete(compiled_package, options = {})
        package = compiled_package.package
        @logger.info('Deleting compiled package: ' +
            "#{package.name}/#{package.version}" +
            "for #{compiled_package.stemcell_os}/#{compiled_package.stemcell_version}")

        errors = []
        if @blob_deleter.delete(compiled_package.blobstore_id, errors,  options['force'])
          compiled_package.destroy
        end
        errors
      end
    end
  end
end
