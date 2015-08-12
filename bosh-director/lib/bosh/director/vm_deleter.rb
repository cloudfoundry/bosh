module Bosh::Director
  class VmDeleter
    def initialize(cloud,logger)
      @cloud = cloud
      @logger = logger
    end

    def delete_for_instance(instance, options={})
      detach_disks_for(instance) unless options.fetch(:skip_disks, false)

      if instance.vm.model
        delete_vm(instance.vm.model)
        instance.vm.clean
      end

      instance.release_original_network_reservations
    end

    def delete_vm(vm_model)
      @logger.info('Deleting VM')
      @cloud.delete_vm(vm_model.cid)
      vm_model.destroy
    end

    private

    def detach_disks_for(instance)
      disk_cid = instance.model.persistent_disk_cid
      return @logger.info('Skipping disk detaching') if disk_cid.nil?
      @logger.info("Detaching Disk #{disk_cid}")
      vm_model = instance.vm.model
      AgentClient.with_vm(vm_model).unmount_disk(disk_cid)
      @cloud.detach_disk(vm_model.cid, disk_cid)
    end
  end
end
