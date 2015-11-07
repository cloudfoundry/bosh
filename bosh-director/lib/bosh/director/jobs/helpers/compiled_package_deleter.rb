module Bosh::Director::Jobs
  module Helpers
    class CompiledPackageDeleter
      def initialize(blob_deleter, logger)
        @blob_deleter = blob_deleter
        @logger = logger
      end

      def delete(compiled_package, options = {})
        package = compiled_package.package
        stemcell = compiled_package.stemcell
        @logger.info('Deleting compiled package: ' +
            "#{package.name}/#{package.version}" +
            "for #{stemcell.name}/#{stemcell.version}")

        errors = []
        if @blob_deleter.delete(compiled_package.blobstore_id, errors,  options['force'])
          compiled_package.destroy
        end
        errors
      end
    end
  end
end
