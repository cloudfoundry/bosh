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
        parent_id = add_event
        with_deployment_lock(@deployment_name) do
          deployment_model = @deployment_manager.find_by_name(@deployment_name)

          ip_provider = DeploymentPlan::IpProviderFactory.new(true, logger)

          dns_manager = DnsManagerProvider.create
          disk_manager = DiskManager.new(@cloud, logger)
          instance_deleter = InstanceDeleter.new(ip_provider, dns_manager, disk_manager, force: @force)
          deployment_deleter = DeploymentDeleter.new(Config.event_log, logger, dns_manager, Config.max_threads)

          vm_deleter = Bosh::Director::VmDeleter.new(@cloud, logger, force: @force)
          deployment_deleter.delete(deployment_model, instance_deleter, vm_deleter)
          add_event(parent_id)

          "/deployments/#{@deployment_name}"
        end
      rescue Exception => e
        add_event(parent_id, e)
        raise e
      end

      private
      def add_event(parent_id = nil, error = nil)
        @user  = @user ||= task_manager.find_task(task_id).username
        event  = event_manager.create_event(
            {
                parent_id:   parent_id,
                user:        @user,
                action:      "delete",
                object_type: "deployment",
                object_name: @deployment_name,
                task:        task_id,
                error:       error
            })
        event.id
      end
    end
  end
end
