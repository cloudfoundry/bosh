module Bosh::Director
  module Jobs
    class DeleteStemcell
      extend BaseJob

      @queue = :normal

      def initialize(*args)
        if args.length == 2
          @name, @version = args
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

        lock = Lock.new("lock:stemcells:#{@name}:#{@version}", :timeout => 10)
        lock.lock do
          @logger.info("Looking up stemcell: #{@name}:#{@version}")
          @stemcell = Models::Stemcell.find(:name => @name, :version => @version).first
          raise StemcellNotFound.new(@name, @version) if @stemcell.nil?
          @logger.info("Found: #{@stemcell.pretty_inspect}")

          @logger.info("Checking for any deployments still using the stemcell..")
          unless @stemcell.deployments.empty?
            deployments = []
            @stemcell.deployments.each { |deployment| deployments << deployment.name }
            raise StemcellInUse.new(@name, @version, deployments.join(", "))
          end

          @logger.info("Deleting stemcell from the cloud")
          @cloud.delete_stemcell(@stemcell.cid)
          @logger.info("Deleting stemcell meta")
          @stemcell.delete
        end

        nil
      end

    end
  end
end
