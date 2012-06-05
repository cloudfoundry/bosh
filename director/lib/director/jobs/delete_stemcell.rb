# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Jobs
    class DeleteStemcell < BaseJob

      @queue = :normal

      # @param [String] name Stemcell name
      # @param [String] version Stemcell version
      def initialize(name, version)
        super

        @name = name
        @version = version
        @cloud = Config.cloud
        @blobstore = Config.blobstore
        @stemcell_manager = Api::StemcellManager.new
      end

      def perform
        logger.info("Processing delete stemcell")

        lock = Lock.new("lock:stemcells:#{@name}:#{@version}", :timeout => 10)

        lock.lock do
          desc = "#{@name}/#{@version}"
          logger.info("Looking up stemcell: #{desc}")
          @stemcell =
            @stemcell_manager.find_by_name_and_version(@name, @version)

          logger.info("Found: #{@stemcell.pretty_inspect}")
          logger.info("Checking for any deployments still using the stemcell")

          deployments = @stemcell.deployments
          unless deployments.empty?
            names = deployments.map { |d| d.name }.join(", ")
            raise StemcellInUse,
                  "Stemcell `#{desc}' is still in use by: #{names}"
          end

          event_log.begin_stage("Deleting stemcell from cloud", 1)

          event_log.track("Delete stemcell") do
            @cloud.delete_stemcell(@stemcell.cid)
          end

          logger.info("Looking for any compiled packages on this stemcell")
          compiled_packages =
            Models::CompiledPackage.filter(:stemcell_id => @stemcell.id)

          event_log.begin_stage("Deleting compiled packages",
                                 compiled_packages.count, [@name, @version])
          logger.info("Deleting compiled packages " +
                       "(#{compiled_packages.count}) for `#{desc}'")

          compiled_packages.each do |compiled_package|
            next unless compiled_package

            package = compiled_package.package
            track_and_log("#{package.name}/#{package.version}") do
              logger.info("Deleting compiled package: " +
                          "#{package.name}/#{package.version}")
              @blobstore.delete(compiled_package.blobstore_id)
              compiled_package.destroy
            end
          end

          event_log.begin_stage("Deleting stemcell metadata", 1)
          event_log.track("Deleting stemcell metadata") do
            @stemcell.destroy
          end
        end

        "/stemcells/#{@name}/#{@version}"
      end

    end
  end
end
