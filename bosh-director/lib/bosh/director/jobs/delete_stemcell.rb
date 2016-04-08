module Bosh::Director
  module Jobs
    class DeleteStemcell < BaseJob
      @queue = :normal

      def self.job_type
        :delete_stemcell
      end

      def initialize(name, version, options = {})
        @name = name
        @version = version
        @options = options
        @cloud = Config.cloud
        @stemcell_manager = Api::StemcellManager.new

        blobstore = options.fetch(:blobstore) { App.instance.blobstores.blobstore }
        blob_deleter = Helpers::BlobDeleter.new(blobstore, logger)
        compiled_package_deleter = Helpers::CompiledPackageDeleter.new(blob_deleter, logger)
        @stemcell_deleter = Helpers::StemcellDeleter.new(@cloud, compiled_package_deleter, logger)
      end

      def perform
        logger.info("Processing delete stemcell")

        logger.info("Looking up stemcell: #{@name}/#{@version}")
        stemcell = @stemcell_manager.find_by_name_and_version(@name, @version)
        logger.info("Found: #{stemcell.pretty_inspect}")

        @stemcell_deleter.delete(stemcell, @options)

        "/stemcells/#{@name}/#{@version}"
      end
    end
  end
end
