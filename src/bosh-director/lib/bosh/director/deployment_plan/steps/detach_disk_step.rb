module Bosh::Director
  module DeploymentPlan
    module Steps
      class DetachDiskStep
        include LockHelper

        def initialize(disk)
          @disk = disk
          @logger = Config.logger
        end

        def perform(_report)
          return if @disk.nil?

          instance_active_vm = @disk.instance.active_vm
          return if instance_active_vm.nil?

          agent_client(@disk.instance).remove_persistent_disk(@disk.disk_cid)

          cloud_factory = CloudFactory.create
          cloud = cloud_factory.get(@disk.cpi, instance_active_vm.stemcell_api_version)
          @logger.info("Detaching disk #{@disk.disk_cid}")
          with_vm_lock(@disk.instance.vm_cid) { cloud.detach_disk(@disk.instance.vm_cid, @disk.disk_cid) }
        rescue Bosh::Clouds::DiskNotAttached
          if @disk.active
            raise CloudDiskNotAttached,
                  "'#{@disk.instance}' VM should have persistent disk " \
                  "'#{@disk.disk_cid}' attached but it doesn't (according to CPI)"
          end
        end

        private

        def agent_client(instance_model)
          @agent_client ||= AgentClient.with_agent_id(instance_model.agent_id, instance_model.name)
        end
      end
    end
  end
end
