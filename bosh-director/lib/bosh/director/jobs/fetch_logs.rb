module Bosh::Director
  module Jobs
    class FetchLogs < BaseJob
      include LockHelper

      @queue = :normal

      def self.job_type
        :fetch_logs
      end

      def initialize(instance_id, options = {})
        @instance_id = instance_id
        @log_type = options["type"] || "job"
        @filters = options["filters"]
        @instance_manager = Api::InstanceManager.new

        blobstore = options.fetch(:blobstore) { App.instance.blobstores.blobstore }
        log_bundles_cleaner = LogBundlesCleaner.new(blobstore, 60 * 60 * 24 * 10, logger) # 10 days
        @logs_fetcher = LogsFetcher.new(event_log, @instance_manager, log_bundles_cleaner, logger)
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
          @logs_fetcher.fetch(instance, @log_type, @filters)
        end
      end
    end
  end
end
