module Bosh::Director
  class VmDeleter
    def initialize(cloud, logger, options={})
      @cloud = cloud
      @logger = logger

      force = options.fetch(:force, false)
      @error_ignorer = ErrorIgnorer.new(force, @logger)
    end

    def delete_for_instance_plan(instance_plan)
      instance_model = instance_plan.new? ? instance_plan.instance.model : instance_plan.existing_instance

      if instance_model.vm_cid
        delete_vm(instance_model.vm_cid)
        instance_model.update(vm_cid: nil, agent_id: nil, trusted_certs_sha1: nil, credentials: nil, vm_env_json: nil)
      end
    end

    def delete_vm(vm_cid)
      @logger.info('Deleting VM')
      @error_ignorer.with_force_check { @cloud.delete_vm(vm_cid) }
    end
  end
end
