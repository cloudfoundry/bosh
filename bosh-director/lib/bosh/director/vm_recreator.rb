module Bosh::Director
  class VmRecreator

    def initialize(vm_creator, vm_deleter)
      @vm_creator = vm_creator
      @vm_deleter = vm_deleter
    end

    def recreate_vm(instance_plan, disk_cid)
      @vm_deleter.delete_for_instance_plan(instance_plan)
      disks = [instance_plan.instance.model.persistent_disk_cid, disk_cid].compact
      @vm_creator.create_for_instance_plan(instance_plan, disks)
    end
  end
end
