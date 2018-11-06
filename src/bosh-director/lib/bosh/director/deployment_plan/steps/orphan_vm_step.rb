module Bosh::Director
  module DeploymentPlan
    module Steps
      class OrphanVmStep
        def initialize(vm)
          @vm = vm
          @transactor = Transactor.new
        end

        def perform(_)
          AgentClient.with_agent_id(@vm.agent_id, @vm.instance.name).shutdown

          @transactor.retryable_transaction(Bosh::Director::Config.db) do
            begin
              parent_id = add_event(@vm.instance.deployment.name, @vm.instance.name, @vm.cid)

              orphaned_vm = Models::OrphanedVm.create(
                availability_zone: @vm.instance.availability_zone,
                cid: @vm.cid,
                cloud_properties: @vm.instance.cloud_properties,
                cpi: @vm.cpi,
                deployment_name: @vm.instance.deployment.name,
                instance_name: @vm.instance.name,
                orphaned_at: Time.now,
                stemcell_api_version: @vm.stemcell_api_version,
              )

              @vm.ip_addresses_dataset.all.each do |ip_address|
                ip_address.instance = nil
                ip_address.orphaned_vm = orphaned_vm
                ip_address.save
              end

              @vm.destroy
            rescue Exception => e
              raise e
            ensure
              add_event(@vm.instance.deployment.name, @vm.instance.name, @vm.cid, parent_id, e)
            end
          end
        end

        private

        def add_event(deployment_name, instance_name, object_name = nil, parent_id = nil, error = nil)
          event = Config.current_job.event_manager.create_event(
            parent_id:   parent_id,
            user:        Config.current_job.username,
            action:      'orphan',
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
