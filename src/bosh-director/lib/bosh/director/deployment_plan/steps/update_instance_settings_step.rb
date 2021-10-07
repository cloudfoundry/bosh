module Bosh::Director
  module DeploymentPlan
    module Steps
      class UpdateInstanceSettingsStep
        def initialize(instance)
          @instance = instance
        end

        def perform(report)
          instance_model = @instance.model.reload

          @instance.update_instance_settings(report.vm)

          instance_model.update(cloud_properties: JSON.dump(@instance.cloud_properties))
        end
      end
    end
  end
end
