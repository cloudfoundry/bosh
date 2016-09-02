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

        @stemcell_deleter = Helpers::StemcellDeleter.new(@cloud, logger)
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
