module Bosh::Director
  module Jobs
    class FetchLogs < BaseJob
      include LockHelper

      @queue = :normal

      def self.job_type
        :fetch_logs
      end

      def initialize(instance_id, options = {})
        @blobstore = options.fetch(:blobstore) { App.instance.blobstores.blobstore }
        @instance_id = instance_id
        @log_type = options["type"] || "job"
        @filters = options["filters"]
        @instance_manager = Api::InstanceManager.new
        @log_bundles_cleaner = LogBundlesCleaner.new(@blobstore, 86400 * 10, logger) # 10 days
      end

      def perform
        instance = @instance_manager.find_instance(@instance_id)
        desc = "#{instance.job}/#{instance.index}"

        deployment = instance.deployment

        if deployment.nil?
          raise InstanceDeploymentMissing,
                "`#{desc}' doesn't belong to any deployment"
        end

        with_deployment_lock(deployment) do
          @log_bundles_cleaner.clean

          event_log.begin_stage("Fetching logs for #{desc}", 1)

          agent = @instance_manager.agent_client_for(instance)

          blobstore_id = nil

          track_and_log("Finding and packing log files") do
            logger.info("Fetching logs from agent: log_type='#{@log_type}', filters='#{@filters}'")
            task = agent.fetch_logs(@log_type, @filters)
            blobstore_id = task["blobstore_id"]
          end

          if blobstore_id.nil?
            raise AgentTaskNoBlobstoreId,
                  "Agent didn't return a blobstore object id for packaged logs"
          end

          @log_bundles_cleaner.register_blobstore_id(blobstore_id)

          blobstore_id
        end
      end
    end
  end
end
