module Bosh::Director
  module Jobs
    class DeleteDeployment < BaseJob
      include DnsHelper
      include LockHelper

      @queue = :normal

      def self.job_type
        :delete_deployment
      end

      def initialize(deployment_name, options = {})
        @deployment_name = deployment_name
        @force = options['force']
        @keep_snapshots = options['keep_snapshots']
        @cloud = Config.cloud
        @deployment_manager = Api::DeploymentManager.new
      end

      def perform
        logger.info("Deleting: #{@deployment_name}")

        with_deployment_lock(@deployment_name) do
          deployment_model = @deployment_manager.find_by_name(@deployment_name)

          planner_factory = DeploymentPlan::PlannerFactory.create(event_log, logger)
          deployment_plan = planner_factory.create_from_model(deployment_model)
          deployment_plan.bind_models

          deleter_options = {
            force: @force,
            keep_snapshots_in_the_cloud: @keep_snapshots
          }
          instance_deleter = InstanceDeleter.new(deployment_plan, DeploymentPlan::IpProviderV2.new(DeploymentPlan::IpRepoThatDelegatesToExistingStuff.new), deleter_options)

          dns_manager = DnsManager.new(logger)
          deployment_deleter = DeploymentDeleter.new(event_log, logger, dns_manager, Config.max_threads, Config.dns_enabled?)

          vm_deleter = Bosh::Director::VmDeleter.new(@cloud, logger, force: @force)
          deployment_deleter.delete(deployment_plan, instance_deleter, vm_deleter)

          "/deployments/#{@deployment_name}"
        end
      end
    end
  end
end
