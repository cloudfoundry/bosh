module Bosh::Director
  module DeploymentPlan
    module Steps
      class UpdateInstanceSettingsStep
        def initialize(instance)
          @instance = instance
        end

        def perform(report)
          instance_model = @instance.model.reload

          @instance.update_instance_settings(report.vm, Config.enable_short_lived_nats_bootstrap_credentials)

          instance_model.update(cloud_properties: JSON.dump(@instance.cloud_properties))
          report.vm.update(permanent_nats_credentials: Config.enable_short_lived_nats_bootstrap_credentials)
        end
      end
    end
  end
end
