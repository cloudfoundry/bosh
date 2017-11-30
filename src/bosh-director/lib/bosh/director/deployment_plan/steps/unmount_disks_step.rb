module Bosh::Director
  module DeploymentPlan
    module Steps
      class UnmountDisksStep
        def initialize(instance_plan)
          @instance_plan = instance_plan
          @logger = Config.logger
        end

        def perform
          instance_model = @instance_plan.instance.model
          instance_model.active_persistent_disks.select(&:managed?).each do |disk|
            instance_model = disk.model.instance
            disk_cid = disk.model.disk_cid
            if disk_cid.nil?
              @logger.info('Skipping disk unmounting, instance does not have a disk')
              return
            end

            if agent_client(instance_model).list_disk.include?(disk_cid)
              @logger.info("Unmounting disk '#{disk_cid}'")
              agent_client(instance_model).unmount_disk(disk_cid)
            end
          end
        end

        private

        def agent_client(instance_model)
          @agent_client ||= AgentClient.with_agent_id(instance_model.agent_id)
        end
      end
    end
  end
end
