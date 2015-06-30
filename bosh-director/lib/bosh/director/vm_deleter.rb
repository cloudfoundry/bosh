module Bosh::Director
  class VmDeleter
    def self.delete_for_instance(*args)
      new.delete_for_instance(*args)
    end

    def initialize
      @cloud = Config.cloud
      @logger = Config.logger
    end

    def delete_for_instance(instance)
      detach_disks_for instance
      @logger.info('Deleting VM')
      @cloud.delete_vm(instance.model.vm.cid)
      instance.delete_vm_model
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
