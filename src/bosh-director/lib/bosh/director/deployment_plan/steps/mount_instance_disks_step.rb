module Bosh::Director
  module DeploymentPlan
    module Steps
      class MountInstanceDisksStep
        def initialize(instance)
          @instance = instance
        end

        def perform(report)
          @instance.active_persistent_disks.collection.each do |disk|
            if disk.model.managed?
              MountDiskStep.new(disk.model).perform(report)
            end
          end
        end
      end
    end
  end
end
