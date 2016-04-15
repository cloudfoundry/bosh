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
        begin
          vm_cid = instance.vm_cid
          instance_name = "#{instance.job}/#{instance.uuid}"
          parent_id = add_event(instance.deployment.name, instance_name, vm_cid)
          delete_vm(instance.vm_cid)
          instance.update(vm_cid: nil, agent_id: nil, trusted_certs_sha1: nil, credentials: nil)
        rescue Exception => e
          raise e
        ensure
          add_event(instance.deployment.name, instance_name, vm_cid, parent_id, e)
        end
      end
    end

    def delete_vm(vm_cid)
      @logger.info('Deleting VM')
      @error_ignorer.with_force_check { @cloud.delete_vm(vm_cid) }
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
