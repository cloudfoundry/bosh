module Bosh::Director
  module DeploymentPlan
    module Steps
      class UpdateInstanceSettingsStep
        def initialize(instance_plan)
          @instance_plan = instance_plan
        end

        def perform(report)
          instance_model = @instance_plan.instance.model.reload

          short_lived_nats_credentials = if @instance_plan.instance.compilation?
                                           Config.enable_short_lived_nats_bootstrap_credentials_compilation_vms
                                         else
                                           Config.enable_short_lived_nats_bootstrap_credentials
                                         end

          @instance_plan.instance.update_instance_settings(report.vm, short_lived_nats_credentials)

          instance_model.update(cloud_properties: JSON.dump(@instance_plan.instance.cloud_properties))
          report.vm.update(permanent_nats_credentials: short_lived_nats_credentials)
        end
      end
    end
  end
end
