module Bosh::Director
  class VmDeleter
    def initialize(cloud, logger, options={})
      @cloud = cloud
      @logger = logger

      force = options.fetch(:force, false)
      @error_ignorer = ErrorIgnorer.new(force, @logger)
    end

    def delete_for_instance_plan(instance_plan, options={})
      existing_instance = instance_plan.existing_instance

      detach_disks_for(existing_instance) unless options.fetch(:skip_disks, false)

      if existing_instance.vm
        delete_vm(existing_instance.vm)
      end
    end

    def delete_vm(vm_model)
      @logger.info('Deleting VM')
      @error_ignorer.with_force_check { @cloud.delete_vm(vm_model.cid) }
      vm_model.destroy
    end

    private

    def detach_disks_for(existing_instance)
      disk_cid = existing_instance.persistent_disk_cid
      return @logger.info('Skipping disk detaching') if disk_cid.nil?
      @logger.info("Detaching Disk #{disk_cid}")
      vm_model = existing_instance.vm
      AgentClient.with_vm(vm_model).unmount_disk(disk_cid)
      @cloud.detach_disk(vm_model.cid, disk_cid)
    end
  end
end
