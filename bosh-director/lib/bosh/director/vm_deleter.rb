module Bosh::Director
  class VmDeleter
    def initialize(cloud, logger, force=false, enable_virtual_delete_vm=false)
      @cloud = cloud
      @logger = logger
      @error_ignorer = ErrorIgnorer.new(force, @logger)
      @enable_virtual_delete_vm = enable_virtual_delete_vm
    end

    def delete_for_instance(instance_model, store_event=true)
      if instance_model.vm_cid
        begin
          vm_cid = instance_model.vm_cid
          instance_name = "#{instance_model.job}/#{instance_model.uuid}"
          parent_id = add_event(instance_model.deployment.name, instance_name, vm_cid) if store_event
          delete_vm(instance_model.vm_cid)
          instance_model.update(vm_cid: nil, agent_id: nil, trusted_certs_sha1: nil, credentials: nil)
        rescue Exception => e
          raise e
        ensure
          add_event(instance_model.deployment.name, instance_name, vm_cid, parent_id, e) if store_event
        end
      end
    end

    def delete_vm(vm_cid)
      @logger.info('Deleting VM')
      @error_ignorer.with_force_check do
        @cloud.delete_vm(vm_cid) unless @enable_virtual_delete_vm
      end
    end

    private

    def add_event(deployment_name, instance_name, object_name = nil, parent_id = nil, error = nil)
      event  = Config.current_job.event_manager.create_event(
          {
              parent_id:   parent_id,
              user:        Config.current_job.username,
              action:      'delete',
              object_type: 'vm',
              object_name: object_name,
              task:        Config.current_job.task_id,
              deployment:  deployment_name,
              instance:    instance_name,
              error:       error
          })
      event.id
    end
  end
end
