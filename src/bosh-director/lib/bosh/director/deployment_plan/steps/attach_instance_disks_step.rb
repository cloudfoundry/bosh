module Bosh::Director
  module DeploymentPlan
    module Steps
      class AttachInstanceDisksStep
        def initialize(instance_model, tags)
          @instance_model = instance_model
          @logger = Config.logger
          @tags = tags
        end

        def perform(report)
          return if @instance_model.active_vm.nil?

          @instance_model.active_persistent_disks.collection.each do |disk|
            AttachDiskStep.new(disk.model, @tags).perform(report)
          end
        end
      end
    end
  end
end
