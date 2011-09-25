module Bosh::Director
  module Jobs
    class DeleteStemcell < BaseJob

      @queue = :normal

      def initialize(*args)
        super
        if args.length == 2
          @name, @version = args
          @cloud = Config.cloud
          @blobstore = Config.blobstore
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
          @stemcell = Models::Stemcell[:name => @name, :version => @version]
          raise StemcellNotFound.new(@name, @version) if @stemcell.nil?
          @logger.info("Found: #{@stemcell.pretty_inspect}")

          @logger.info("Checking for any deployments still using the stemcell..")
          unless @stemcell.deployments.empty?
            deployments = []
            @stemcell.deployments.each { |deployment| deployments << deployment.name }
            raise StemcellInUse.new(@name, @version, deployments.join(", "))
          end

          @event_log.begin_stage("Deleting stemcell from cloud", 1, [@name, @version])

          @event_log.track("Delete stemcell") do
            @cloud.delete_stemcell(@stemcell.cid)
          end

          @logger.info("Looking for any compiled packages on this stemcell")
          compiled_packages = Models::CompiledPackage.filter(:stemcell_id => @stemcell.id)

          @event_log.begin_stage("Deleting compiled packages", compiled_packages.count, [@name, @version])
          @logger.info("Deleting compiled packages (#{compiled_packages.count}) for: #{@stemcell.pretty_inspect}")

          compiled_packages.each do |compiled_package|
            next unless compiled_package

            package = compiled_package.package
            track_and_log("#{package.name}/#{package.version}") do
              @logger.info("Deleting compiled package: #{package.name}/#{package.version}")
              @blobstore.delete(compiled_package.blobstore_id)
              compiled_package.destroy
            end
          end

          @event_log.begin_stage("Deleting stemcell metadata", 1, [@name, @version])
          @event_log.track("Deleting stemcell metadata") do
            @stemcell.destroy
          end
        end

        "/stemcells/#{@name}/#{@version}"
      end

    end
  end
end
