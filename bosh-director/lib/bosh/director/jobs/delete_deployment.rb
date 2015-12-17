module Bosh::Director
  module Jobs
    class DeleteDeployment < BaseJob
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

          ip_provider = DeploymentPlan::IpProviderFactory.new(true, logger)

          dns_manager = DnsManager.create
          disk_manager = DiskManager.new(@cloud, logger)
          instance_deleter = InstanceDeleter.new(ip_provider, dns_manager, disk_manager, force: @force)
          deployment_deleter = DeploymentDeleter.new(event_log, logger, dns_manager, Config.max_threads)

          vm_deleter = Bosh::Director::VmDeleter.new(@cloud, logger, force: @force)
          deployment_deleter.delete(deployment_model, instance_deleter, vm_deleter)

          "/deployments/#{@deployment_name}"
        end
      end
    end
  end
end
