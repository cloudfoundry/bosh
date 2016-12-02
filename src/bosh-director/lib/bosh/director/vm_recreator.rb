module Bosh::Director
  class VmRecreator

    def initialize(vm_creator, vm_deleter)
      @vm_creator = vm_creator
      @vm_deleter = vm_deleter
    end

    def recreate_vm(instance_plan, disk_cid, tags)
      instance_model = instance_plan.instance.model
      @vm_deleter.delete_for_instance(instance_model)
      active_disk_cids = instance_model.active_persistent_disks.collection.
        map(&:model).
        map(&:disk_cid)
      disks = [active_disk_cids, disk_cid].flatten.compact
      @vm_creator.create_for_instance_plan(instance_plan, disks, tags)
    end
  end
end
