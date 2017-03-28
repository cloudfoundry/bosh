module Bosh::Director
  class VmDeleter
    include CloudFactoryHelper

    def initialize(logger, force=false, enable_virtual_delete_vm=false)
      @logger = logger
      @error_ignorer = ErrorIgnorer.new(force, @logger)
      @enable_virtual_delete_vm = enable_virtual_delete_vm
    end

    def delete_for_instance(instance_model, store_event=true)
      if instance_model.active_vm
        begin
          vm_model = instance_model.active_vm
          instance_name = "#{instance_model.job}/#{instance_model.uuid}"
          parent_id = add_event(instance_model.deployment.name, instance_name, vm_model.cid) if store_event
          delete_vm(instance_model)
          instance_model.update(active_vm: nil)
          vm_model.delete
        rescue Exception => e
          raise e
        ensure
          add_event(instance_model.deployment.name, instance_name, vm_model.cid, parent_id, e) if store_event
        end
      end
    end

    def delete_vm(instance_model)
      @logger.info('Deleting VM')
      @error_ignorer.with_force_check do
        cloud = cloud_factory.for_availability_zone(instance_model.availability_zone)

        begin
          cloud.delete_vm(instance_model.active_vm.cid) unless @enable_virtual_delete_vm
        rescue Bosh::Clouds::VMNotFound
          @logger.warn("VM '#{instance_model.active_vm.cid}' might have already been deleted from the cloud")
        end
      end
    end

    def delete_vm_by_cid(cid)
      @logger.info('Deleting VM')
      @error_ignorer.with_force_check do
        # if there are multiple cpis, it's too dangerous to try and delete just vm cid on every cloud.
        unless cloud_factory.uses_cpi_config?
          cloud_factory.default_from_director_config.delete_vm(cid) unless @enable_virtual_delete_vm
        end
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
