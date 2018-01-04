module Bosh::Director
  module DeploymentPlan
    module Steps
      class UnmountInstanceDisksStep
        def initialize(instance_model)
          @instance_model = instance_model
          @logger = Config.logger
        end

        def perform(report)
          @instance_model.active_persistent_disks.select(&:managed?).each do |disk|
            UnmountDiskStep.new(disk.model).perform(report)
          end
        end
      end
    end
  end
end
