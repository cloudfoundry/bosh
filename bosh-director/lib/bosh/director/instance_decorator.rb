module Bosh::Director
  class InstanceDecorator
    def initialize(instance_model)
      @instance_model = instance_model
    end

    def lifecycle
      deployment = @instance_model.deployment
      return nil if deployment.manifest == nil

      deployment_plan = create_deployment_plan_from_manifest(deployment)
      instance_group = deployment_plan.instance_group(@instance_model.job)
      if instance_group
        instance_group.lifecycle
      else
        nil
      end
    end

    private

    def create_deployment_plan_from_manifest(deployment)
      planner_factory = Bosh::Director::DeploymentPlan::PlannerFactory.create(Config.logger)
      manifest = Manifest.load_from_text(deployment.manifest, deployment.cloud_config, deployment.runtime_config, true)
      planner_factory.create_from_manifest(manifest, deployment.cloud_config, deployment.runtime_config, {})
    end
  end
end