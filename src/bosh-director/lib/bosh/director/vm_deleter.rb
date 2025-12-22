module Bosh::Director
  class VmDeleter
    include LockHelper

    def initialize(logger, force = false, enable_virtual_delete_vm = false)
      @logger = logger
      @error_ignorer = ErrorIgnorer.new(force, @logger)
      @enable_virtual_delete_vm = enable_virtual_delete_vm
      @force = force
    end

    def delete_for_instance(instance_model, store_event = true, async = false)
      if async && instance_model.orphanable?
        unmount_and_detach_disk(instance_model)
        orphan_vms(instance_model)
      else
        delete_vms(instance_model, store_event)
      end
    end

    def delete_vm_by_cid(cid, stemcell_api_version, cpi_name = nil)
      @logger.info('Deleting VM')
      @error_ignorer.with_force_check do
        cloud_factory = CloudFactory.create
        with_vm_lock(cid) { cloud_factory.get(cpi_name, stemcell_api_version).delete_vm(cid) } unless @enable_virtual_delete_vm
      end
    end

    private

    def delete_vms(instance_model, store_event)
      instance_model.vms.each do |vm|
        DeploymentPlan::Steps::DeleteVmStep.new(
          store_event,
          @force,
          @enable_virtual_delete_vm,
        ).perform(DeploymentPlan::Stages::Report.new.tap { |r| r.vm = vm })
      end
    end

    def unmount_and_detach_disk(instance_model)
      return if instance_model.vms.empty?
      DeploymentPlan::Steps::UnmountInstanceDisksStep.new(instance_model).perform(DeploymentPlan::Stages::Report.new)
      DeploymentPlan::Steps::DetachInstanceDisksStep.new(instance_model).perform(DeploymentPlan::Stages::Report.new)
    end

    def orphan_vms(instance_model)
      instance_model.vms.each do |vm|
        DeploymentPlan::Steps::OrphanVmStep.new(vm).perform(DeploymentPlan::Stages::Report.new)
      end
    end
  end
end
