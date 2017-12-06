module Bosh::Director
  module DeploymentPlan
    module Steps
      class AttachInstanceDisksStep
        def initialize(instance_model, tags)
          @instance_model = instance_model
          @logger = Config.logger
          @tags = tags
        end

        def perform
          return if @instance_model.active_vm.nil?

          @instance_model.persistent_disks.each do |disk|
            AttachDiskStep.new(disk, @tags).perform
          end
        end
      end
    end
  end
end
