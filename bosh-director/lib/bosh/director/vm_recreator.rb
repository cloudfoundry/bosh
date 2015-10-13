module Bosh::Director
  class VmRecreator

    def initialize(vm_creator, vm_deleter, job_renderer)
      @vm_creator = vm_creator
      @vm_deleter = vm_deleter
      @job_renderer = job_renderer
    end

    def recreate_vm(instance_plan, disk_cid)
      @vm_deleter.delete_for_instance_plan(instance_plan)
      disks = [instance_plan.instance.model.persistent_disk_cid, disk_cid].compact
      @vm_creator.create_for_instance_plan(instance_plan, disks)

      #TODO: we only render the templates again because dynamic networking may have
      #      assigned an ip address, so the state we got back from the @agent may
      #      result in a different instance.template_spec.  Ideally, we clean up the @agent interaction
      #      so that we only have to do this once.
      @job_renderer.render_job_instance(instance_plan.instance)
    end
  end
end
