module Bosh::Director
  class Errand::JobManager
    # @param [Bosh::Director::DeploymentPlan::Planner] deployment
    # @param [Bosh::Director::DeploymentPlan::Job] job
    # @param [Bosh::Blobstore::Client] blobstore
    # @param [Bosh::Director::EventLog::Log] event_log
    def initialize(deployment, job, blobstore, event_log)
      @deployment = deployment
      @job = job
      @blobstore = blobstore
      @event_log = event_log
    end

    # Creates/updates all job instances
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

    # Deletes created all job instances
    # @return [void]
    def delete_instances
      instances = @job.instances.map(&:model).compact
      return if instances.empty?

      event_log_stage = @event_log.begin_stage(
        'Deleting instances', instances.size, [@job.name])

      instance_deleter = InstanceDeleter.new(@deployment)
      instance_deleter.delete_instances(instances, event_log_stage)

      deallocate_vms
    end

    private

    def deallocate_vms
      instance_cids = @job.instances.map { |i| i.model.vm.cid }

      instance_cids.each do |cid|
        idle_vm = @job.resource_pool.deallocate_vm(cid)
        idle_vm.clean_vm
      end
    end
  end
end
