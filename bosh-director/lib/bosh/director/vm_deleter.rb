module Bosh::Director
  class VmDeleter
    def initialize(cloud, logger, options={})
      @cloud = cloud
      @logger = logger

      force = options.fetch(:force, false)
      @error_ignorer = ErrorIgnorer.new(force, @logger)
    end

    def delete_for_instance(instance)
      if instance.vm_cid
        delete_vm(instance.vm_cid)
        instance.update(vm_cid: nil, agent_id: nil, trusted_certs_sha1: nil, credentials: nil)
      end
    end

    def delete_vm(vm_cid)
      @logger.info('Deleting VM')
      @error_ignorer.with_force_check { @cloud.delete_vm(vm_cid) }
    end
  end
end
