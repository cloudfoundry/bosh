module Bosh::Director
  module DeploymentPlan
    module Steps
      class DetachInstanceDisksStep
        def initialize(instance_model)
          @instance_model = instance_model
          @logger = Config.logger
        end

        def perform(report)
          return if @instance_model.active_vm.nil?

          @instance_model.persistent_disks.each do |disk|
            DetachDiskStep.new(disk).perform(report)
          end

          @instance_model.active_vm.dynamic_disks.each do |disk|
            DetachDynamicDiskStep.new(disk).perform(report)
          end
        end
      end
    end
  end
end
