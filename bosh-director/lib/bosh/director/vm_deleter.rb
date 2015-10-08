module Bosh::Director
  class VmDeleter
    def initialize(cloud, logger, options={})
      @cloud = cloud
      @logger = logger

      force = options.fetch(:force, false)
      @error_ignorer = ErrorIgnorer.new(force, @logger)
    end

    def delete_for_instance_plan(instance_plan, options={})
      instance_model = instance_plan.new? ? instance_plan.instance.model : instance_plan.existing_instance

      detach_disks_for(instance_model) unless options.fetch(:skip_disks, false)

      if instance_model.vm
        delete_vm(instance_model.vm)
      end
    end

    def delete_vm(vm_model)
      @logger.info('Deleting VM')
      @error_ignorer.with_force_check { @cloud.delete_vm(vm_model.cid) }
      vm_model.destroy
    end

    private

    def detach_disks_for(instance_model)
      disk_cid = instance_model.persistent_disk_cid
      return @logger.info('Skipping disk detaching') if disk_cid.nil?
      @logger.info("Detaching Disk #{disk_cid}")
      vm_model = instance_model.vm
      AgentClient.with_vm(vm_model).unmount_disk(disk_cid)
      @cloud.detach_disk(vm_model.cid, disk_cid)
    end
  end
end
