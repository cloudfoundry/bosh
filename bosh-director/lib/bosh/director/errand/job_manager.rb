module Bosh::Director
  class Errand::JobManager
    # @param [Bosh::Director::DeploymentPlan::Planner] deployment
    # @param [Bosh::Director::DeploymentPlan::Job] job
    # @param [Bosh::Blobstore::Client] blobstore
    # @param [Bosh::Director::EventLog::Log] event_log
    # @param [Logger] logger
    def initialize(deployment, job, blobstore, event_log, logger)
      @deployment = deployment
      @job = job
      @blobstore = blobstore
      @event_log = event_log
      @logger = logger
    end

    def prepare
      @job.bind_unallocated_vms
      @job.bind_instance_networks
    end

    # Creates/updates all errand job instances
    # @return [void]
    def update_instances
      dns_binder = DeploymentPlan::DnsBinder.new(@deployment)
      dns_binder.bind_deployment

      instance_vm_binder = DeploymentPlan::InstanceVmBinder.new(@event_log)
      instance_vm_binder.bind_instance_vms(@job.instances)

      job_renderer = JobRenderer.new(@job, @blobstore)
      job_renderer.render_job_instances

      job_updater = JobUpdater.new(@deployment, @job, job_renderer)
      job_updater.update
    end

    # Deletes all errand job instances
    # @return [void]
    def delete_instances
      instances = @job.instances.map(&:model).compact
      if instances.empty?
        @logger.info('No errand instances to delete')
        return
      end

      @logger.info('Deleting errand instances')
      event_log_stage = @event_log.begin_stage('Deleting errand instances', instances.size, [@job.name])
      instance_deleter = InstanceDeleter.new(@deployment)
      instance_deleter.delete_instances(instances, event_log_stage)

      deallocate_vms
    end

    private

    # Deallocates all errand VMs
    # @return [void]
    def deallocate_vms
      @logger.info('Deallocating errand VMs')
      instance_vm_cids = @job.instances.map { |instance| instance.model.vm.cid }
      instance_vm_cids.each { |cid| @job.resource_pool.deallocate_vm(cid) }
    end
  end
end
