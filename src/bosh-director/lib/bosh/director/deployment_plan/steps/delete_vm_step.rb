module Bosh::Director
  module DeploymentPlan
    module Steps
      class DeleteVmStep
        def initialize(logger, instance_model, store_event=true, force=false, enable_virtual_delete_vm=false)
          @instance_model = instance_model
          @store_event = store_event
          @logger = logger
          @error_ignorer = ErrorIgnorer.new(force, @logger)
          @enable_virtual_delete_vm = enable_virtual_delete_vm
        end

        attr_reader :instance_model, :store_event, :enable_virtual_delete_vm

        def perform
          # FIXME: stop using active vm
          if instance_model.active_vm
            begin
              vm_model = instance_model.active_vm
              vm_cid = vm_model.cid
              instance_name = "#{instance_model.job}/#{instance_model.uuid}"
              parent_id = add_event(instance_model.deployment.name, instance_name, vm_cid) if store_event

              @logger.info('Deleting VM')
              @error_ignorer.with_force_check do
                cloud = CloudFactory.create_with_latest_configs.get(vm_model.cpi)

                begin
                  cloud.delete_vm(vm_cid) unless @enable_virtual_delete_vm
                rescue Bosh::Clouds::VMNotFound
                  @logger.warn("VM '#{vm_cid}' might have already been deleted from the cloud")
                end
              end

              instance_model.active_vm = nil
              vm_model.delete
            rescue Exception => e
              raise e
            ensure
              add_event(instance_model.deployment.name, instance_name, vm_cid, parent_id, e) if store_event
            end
          end
        end

        private

        def add_event(deployment_name, instance_name, object_name = nil, parent_id = nil, error = nil)
          event = Config.current_job.event_manager.create_event(
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
  end
end
