require 'pp' # for #pretty_inspect

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
        @stemcell_manager = Api::StemcellManager.new

        @stemcell_deleter = Helpers::StemcellDeleter.new(logger)
      end

      def perform
        logger.info('Processing delete stemcell')

        logger.info("Looking up stemcell: #{@name}/#{@version}")

        Models::StemcellUpload.where(name: @name, version: @version).delete

        stemcells_to_delete = @stemcell_manager.all_by_name_and_version(@name, @version)
        raise StemcellNotFound, "Stemcell '#{@name}/#{@version}' doesn't exist" if stemcells_to_delete.empty?
        stemcells_to_delete.each do |stemcell|
          logger.info("Found: #{stemcell.pretty_inspect}")
          @stemcell_deleter.delete(stemcell, @options)
        end

        "/stemcells/#{@name}/#{@version}"
      end
    end
  end
end
