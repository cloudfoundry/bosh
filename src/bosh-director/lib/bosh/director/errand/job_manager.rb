module Bosh::Director
  class Errand::JobManager
    def initialize(deployment, job, logger)
      @deployment = deployment
      @job = job
      @logger = logger
      @disk_manager = DiskManager.new(logger)
      @job_renderer = @deployment.job_renderer
      agent_broadcaster = AgentBroadcaster.new
      @dns_manager = DnsManagerProvider.create
      @vm_deleter = Bosh::Director::VmDeleter.new(logger, false, Config.enable_virtual_delete_vms)
      @vm_creator = Bosh::Director::VmCreator.new(logger, @vm_deleter, @disk_manager, @job_renderer, agent_broadcaster)
    end

    def create_missing_vms
      @vm_creator.create_for_instance_plans(@job.instance_plans_with_missing_vms, @deployment.ip_provider, @deployment.tags)
    end

    # Creates/updates all errand job instances
    # @return [void]
    def update_instances
      job_updater = JobUpdater.new(@deployment.ip_provider, @job, @disk_manager, @job_renderer)
      job_updater.update
    end

    def delete_vms
      bound_instance_plans = @job.needed_instance_plans.reject { |instance_plan| instance_plan.instance.model.nil? }
      if bound_instance_plans.empty?
        @logger.info('No errand vms to delete')
        return
      end

      bound_instance_plans.each do |instance_plan|
        unless instance_plan.already_detached?
          @disk_manager.unmount_disk_for(instance_plan)
        end

        @vm_deleter.delete_for_instance(instance_plan.instance.model)
      end
    end

    private

    def bound_instance_plans
      @job.needed_instance_plans.reject { |instance_plan| instance_plan.instance.model.nil? }
    end
  end
end
