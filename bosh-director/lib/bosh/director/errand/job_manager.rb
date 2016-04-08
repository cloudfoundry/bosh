module Bosh::Director
  class Errand::JobManager
    # @param [Bosh::Director::DeploymentPlan::Planner] deployment
    # @param [Bosh::Director::DeploymentPlan::Job] job
    # @param [Bosh::Clouds] cloud
    # @param [Logger] logger
    def initialize(deployment, job, cloud, logger)
      @deployment = deployment
      @job = job
      @logger = logger
      vm_deleter = Bosh::Director::VmDeleter.new(cloud, logger)
      @disk_manager = DiskManager.new(cloud, logger)
      @job_renderer = JobRenderer.create
      arp_flusher = ArpFlusher.new
      @vm_creator = Bosh::Director::VmCreator.new(cloud, logger, vm_deleter, @disk_manager, @job_renderer, arp_flusher)
    end

    def create_missing_vms
      @vm_creator.create_for_instance_plans(@job.instance_plans_with_missing_vms, @deployment.ip_provider)
    end

    # Creates/updates all errand job instances
    # @return [void]
    def update_instances
      links_resolver = DeploymentPlan::LinksResolver.new(@deployment, @logger)
      job_updater = JobUpdater.new(@deployment, @job, links_resolver, @disk_manager)
      job_updater.update
    end

    # Deletes all errand job instances
    # @return [void]
    def delete_instances
      instance_plans = bound_instance_plans
      if instance_plans.empty?
        @logger.info('No errand instances to delete')
        return
      end

      @logger.info('Deleting errand instances')
      event_log_stage = Config.event_log.begin_stage('Deleting errand instances', instance_plans.size, [@job.name])
      dns_manager = DnsManagerProvider.create
      instance_deleter = InstanceDeleter.new(@deployment.ip_provider, dns_manager, @disk_manager)
      instance_deleter.delete_instance_plans(instance_plans, event_log_stage)
    end

    private

    def bound_instance_plans
      @job.needed_instance_plans.reject { |instance_plan| instance_plan.instance.model.nil? }
    end
  end
end
