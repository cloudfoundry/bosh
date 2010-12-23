module Bosh::Director
  module Jobs
    class DeleteStemcell
      extend BaseJob

      @queue = :normal

      def initialize(*args)
        if args.length == 2
          stemcell_name, stemcell_version = args
          @name = stemcell_name
          @version = stemcell_version
          @cloud = Config.cloud
          @logger = Config.logger
        elsif args.empty?
          # used for testing only
        else
          raise ArgumentError, "wrong number of arguments (#{args.length} for 2)"
        end
      end

      def perform
        @logger.info("Processing delete stemcell")

        @logger.info("Looking up stemcell: #{@name}:#{@version}")
        @stemcell = Models::Stemcell.find(:name => @name, :version => @version).first
        raise StemcellNotFound.new(@name, @version) if @stemcell.nil?
        @logger.info("Found: #{@stemcell.pretty_inspect}")

        @logger.info("Deleting stemcell from the cloud")
        @cloud.delete_stemcell(@stemcell.cid)
        @logger.info("Deleting stemcell meta")
        @stemcell.delete
        nil
      end

    end
  end
end
