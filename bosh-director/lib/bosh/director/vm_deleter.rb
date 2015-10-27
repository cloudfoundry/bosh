module Bosh::Director
  class VmDeleter
    def initialize(cloud, logger, options={})
      @cloud = cloud
      @logger = logger

      force = options.fetch(:force, false)
      @error_ignorer = ErrorIgnorer.new(force, @logger)
    end

    def delete_for_instance_plan(instance_plan)
      instance_model = instance_plan.instance_model

      if instance_model.vm
        delete_vm(instance_model.vm)
      end
    end

    def delete_vm(vm_model)
      @logger.info('Deleting VM')
      @error_ignorer.with_force_check { @cloud.delete_vm(vm_model.cid) }
      vm_model.destroy
    end
  end
end
