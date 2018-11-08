module Bosh::Director
  module DeploymentPlan
    module Steps
      class MountDiskStep
        def initialize(disk)
          @disk = disk
          @logger = Config.logger
        end

        def perform(_report)
          return if @disk.nil?

          instance_model = @disk.instance
          disk_cid = @disk.disk_cid

          agent_client(instance_model).wait_until_ready
          @logger.info("Mounting disk '#{disk_cid}' for instance '#{instance_model}'")
          agent_client(instance_model).mount_disk(disk_cid)
        end

        private

        def agent_client(instance_model)
          @agent_client ||= AgentClient.with_agent_id(instance_model.agent_id, instance_model.name)
        end
      end
    end
  end
end
