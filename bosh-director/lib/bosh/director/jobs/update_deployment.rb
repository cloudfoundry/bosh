module Bosh::Director
  module Jobs
    class UpdateDeployment < BaseJob
      include LockHelper

      @queue = :normal

      def self.job_type
        :update_deployment
      end

      def initialize(manifest_file_path, cloud_config_id, options = {})
        @blobstore = App.instance.blobstores.blobstore
        @manifest_file_path = manifest_file_path
        @options = options
        @cloud_config_id = cloud_config_id
      end

      def perform
        logger.info('Reading deployment manifest')
        manifest_text = File.read(@manifest_file_path)
        logger.debug("Manifest:\n#{manifest_text}")
        deployment_manifest_hash = Psych.load(manifest_text)
        deployment_name = deployment_manifest_hash['name']
        with_deployment_lock(deployment_name) do
          @notifier = DeploymentPlan::Notifier.new(deployment_name, Config.nats_rpc, logger)
          @notifier.send_start_event

          cloud_config_model = Bosh::Director::Models::CloudConfig[@cloud_config_id]
          planner_factory = DeploymentPlan::PlannerFactory.create(event_log, logger)
          deployment_plan = planner_factory.planner(deployment_manifest_hash, cloud_config_model, @options)

          update_step(deployment_plan).perform
          @notifier.send_end_event
          logger.info('Finished updating deployment')

          "/deployments/#{deployment_plan.name}"
        end
      rescue Exception => e
        begin
          @notifier.send_error_event e
        rescue Exception => e2
          # log the second error
        ensure
          raise e
        end
      ensure
        FileUtils.rm_rf(@manifest_file_path)
      end

      private

      # Job tasks

      def update_step(deployment_plan)
        resource_pool_updaters = deployment_plan.resource_pools.map do |resource_pool|
          ResourcePoolUpdater.new(resource_pool)
        end
        resource_pools = DeploymentPlan::ResourcePools.new(event_log, resource_pool_updaters)
        DeploymentPlan::Steps::UpdateStep.new(
          self,
          event_log,
          resource_pools,
          deployment_plan,
          multi_job_updater,
          Config.cloud,
          App.instance.blobstores.blobstore
        )
      end

      # Job dependencies

      def multi_job_updater
        @multi_job_updater ||= begin
          DeploymentPlan::BatchMultiJobUpdater.new(JobUpdaterFactory.new(@blobstore))
        end
      end
    end
  end
end
