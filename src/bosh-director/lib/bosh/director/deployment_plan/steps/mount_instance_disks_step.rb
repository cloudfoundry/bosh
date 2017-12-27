module Bosh::Director
  module DeploymentPlan
    module Steps
      class MountInstanceDisksStep
        def initialize(instance)
          @instance = instance
        end

        def perform
          @instance.active_persistent_disks.collection.each do |disk|
            if disk.model.managed?
              MountDiskStep.new(disk.model).perform
            end
          end
        end
      end
    end
  end
end
