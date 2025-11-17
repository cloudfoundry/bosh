module Bosh::Director
  module DeploymentPlan
    module Steps
      class DeleteVmStep
        include LockHelper

        def initialize(store_event = true, force = false, enable_virtual_delete_vm = false)
          @store_event = store_event
          @logger = Config.logger
          @error_ignorer = ErrorIgnorer.new(force, @logger)
          @enable_virtual_delete_vm = enable_virtual_delete_vm
        end

        attr_reader :store_event, :enable_virtual_delete_vm

        def perform(report)
          vm = report.vm
          instance_model = vm.instance
          begin
            vm_cid = vm.cid
            instance_name = "#{instance_model.job}/#{instance_model.uuid}"
            parent_id = add_event(instance_model.deployment.name, instance_name, vm_cid) if store_event

            @logger.info('Deleting VM')
            @error_ignorer.with_force_check do
              cloud = CloudFactory.create.get(vm.cpi, vm.stemcell_api_version)

              begin
                with_vm_lock(vm_cid) { cloud.delete_vm(vm_cid) } unless @enable_virtual_delete_vm
              rescue Bosh::Clouds::VMNotFound
                @logger.warn("VM '#{vm_cid}' might have already been deleted from the cloud")
              end
            end

            vm.destroy
          rescue Exception => e
            #TODO [gdey]: just a monkey patch
            raise e unless e.message.include?("Attempt to delete object did not result in a single row modification")
          ensure
            add_event(instance_model.deployment.name, instance_name, vm_cid, parent_id, e) if store_event
          end
        end

        private

        def add_event(deployment_name, instance_name, object_name = nil, parent_id = nil, error = nil)
          event = Config.current_job.event_manager.create_event(
            parent_id:   parent_id,
            user:        Config.current_job.username,
            action:      'delete',
            object_type: 'vm',
            object_name: object_name,
            task:        Config.current_job.task_id,
            deployment:  deployment_name,
            instance:    instance_name,
            error:       error,
          )
          event.id
        end
      end
    end
  end
end
