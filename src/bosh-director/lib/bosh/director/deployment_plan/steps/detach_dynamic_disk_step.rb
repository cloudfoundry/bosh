module Bosh::Director
  module DeploymentPlan
    module Steps
      class DetachDynamicDiskStep
        def initialize(disk)
          @disk = disk
          @logger = Config.logger
        end

        def perform(_report)
          return if @disk.nil? || @disk.vm.nil?

          cloud = CloudFactory.create.get(@disk.cpi, @disk.vm.stemcell_api_version)
          @logger.info("Detaching dynamic disk #{@disk.disk_cid}")

          instance_name = @disk.vm.instance.nil? ? nil : @disk.vm.instance.name
          agent_client = AgentClient.with_agent_id(@disk.vm.agent_id, instance_name)
          agent_client.remove_dynamic_disk(@disk.disk_cid)

          cloud.detach_disk(@disk.vm.cid, @disk.disk_cid)
          @disk.update(vm_id: nil)
        rescue Bosh::Clouds::DiskNotAttached
          raise CloudDiskNotAttached,
                "'#{@disk.vm.cid}' VM should have dynamic disk " \
                  "'#{@disk.disk_cid}' attached but it doesn't (according to CPI)"
        end
      end
    end
  end
end
