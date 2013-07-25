# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Jobs
    class DeleteStemcell < BaseJob
      include LockHelper

      @queue = :normal

      def self.job_type
        :delete_stemcell
      end

      # @param [String] name Stemcell name
      # @param [String] version Stemcell version
      def initialize(name, version, options = {})
        @name = name
        @version = version
        @options = options
        @cloud = Config.cloud
        @blobstore = options.fetch(:blobstore) { App.instance.blobstores.blobstore }
        @stemcell_manager = Api::StemcellManager.new
      end

      def perform
        logger.info("Processing delete stemcell")
        with_stemcell_lock(@name, @version) do
          logger.info("Looking up stemcell: #{desc}")
          @stemcell = @stemcell_manager.find_by_name_and_version(@name, @version)
          logger.info("Found: #{@stemcell.pretty_inspect}")

          validate_deletion
          delete_from_cloud
          cleanup_compiled_packages
          delete_stemcell_metadata
        end

        "/stemcells/#{@name}/#{@version}"
      end

      def validate_deletion
        logger.info("Checking for any deployments still using the stemcell")
        deployments = @stemcell.deployments
        unless deployments.empty?
          names = deployments.map { |d| d.name }.join(", ")
          raise StemcellInUse,
                "Stemcell `#{desc}' is still in use by: #{names}"
        end
      end

      def delete_from_cloud
        event_log.begin_stage("Deleting stemcell from cloud", 1)

        event_log.track("Delete stemcell") do
          @cloud.delete_stemcell(@stemcell.cid)
        end
      rescue => e
        raise unless force?
        logger.warn(e.backtrace.join("\n"))
        logger.info("Force deleting is set, ignoring exception: #{e.message}")
      end

      def cleanup_compiled_packages
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
      end

      def delete_stemcell_metadata
        event_log.begin_stage("Deleting stemcell metadata", 1)
        event_log.track("Deleting stemcell metadata") do
          @stemcell.destroy
        end
      end

      def desc
        "#@name/#@version"
      end

      def force?
        @options["force"]
      end
    end
  end
end
