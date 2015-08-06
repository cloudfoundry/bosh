module Bosh::Director
  class Errand::JobManager
    # @param [Bosh::Director::DeploymentPlan::Planner] deployment
    # @param [Bosh::Director::DeploymentPlan::Job] job
    # @param [Bosh::Blobstore::Client] blobstore
    # @param [Bosh::Clouds] cloud
    # @param [Bosh::Director::EventLog::Log] event_log
    # @param [Logger] logger
    def initialize(deployment, job, blobstore, cloud, event_log, logger)
      @deployment = deployment
      @job = job
      @blobstore = blobstore
      @event_log = event_log
      @logger = logger
      vm_deleter = Bosh::Director::VmDeleter.new(cloud, logger)
      @vm_creator = Bosh::Director::VmCreator.new(cloud, logger, vm_deleter)
    end

    def prepare
      @job.bind_instances
    end

    def create_missing_vms
      @vm_creator.create_for_instances(@job.instances_with_missing_vms, @event_log)
    end

    # Creates/updates all errand job instances
    # @return [void]
    def update_instances
      dns_binder = DeploymentPlan::DnsBinder.new(@deployment)
      dns_binder.bind_deployment

      job_renderer = JobRenderer.new(@job, @blobstore)
      links_resolver = DeploymentPlan::LinksResolver.new(@deployment, @logger)
      job_updater = JobUpdater.new(@deployment, @job, job_renderer, links_resolver)
      job_updater.update
    end

    # Deletes all errand job instances
    # @return [void]
    def delete_instances
      instances = bound_instances
      if bound_instances.empty?
        @logger.info('No errand instances to delete')
        return
      end

      @logger.info('Deleting errand instances')
      event_log_stage = @event_log.begin_stage('Deleting errand instances', instances.size, [@job.name])
      instance_deleter = InstanceDeleter.new(@deployment)
      instance_deleter.delete_instances(instances, event_log_stage)
    end

    def bound_instances
      @job.instances.select { |i| !i.model.nil? }
    end
  end
end
