require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe InstancePlanFromDB do
      let(:instance_model) do
        Models::Instance.make(
          deployment: deployment_model,
          spec: spec,
          variable_set: variable_set_model,
          job: 'foobar',
        )
      end

      let(:stemcell) { FactoryBot.create(:models_stemcell, name: 'stemcell-name', version: '3.0.2', cid: 'sc-302') }
      let(:spec) do
        {
          'vm_type' => {
            'name' => 'vm-type-name',
            'cloud_properties' => {},
          },
          'stemcell' => {
            'name' => stemcell.name,
            'version' => stemcell.version,
          },
          'networks' => {},
        }
      end
      let(:variable_set_model) { FactoryBot.create(:models_variable_set, deployment: deployment_model) }
      let(:cloud_config_manifest) { Bosh::Spec::Deployments.simple_cloud_config }

      let(:deployment_manifest) { Bosh::Spec::Deployments.simple_manifest_with_instance_groups }
      let(:deployment_model) do
        cloud_config = FactoryBot.create(:models_config_cloud, content: YAML.dump(cloud_config_manifest))
        deployment = FactoryBot.create(:models_deployment,
          name: deployment_manifest['name'],
          manifest: YAML.dump(deployment_manifest),
        )
        deployment.cloud_configs = [cloud_config]
        deployment
      end
      let(:deployment_plan) do
        planner_factory = PlannerFactory.create(logger)
        planner_factory.create_from_model(deployment_model)
      end

      before do
        release = FactoryBot.create(:models_release, name: 'bosh-release')
        release_version = FactoryBot.create(:models_release_version, version: '0.1-dev', release: release)
        template1 = FactoryBot.create(:models_template, name: 'foobar', release: release)
        release_version.add_template(template1)
      end

      describe '.create_from_instance_model' do
        it 'can create an instance plan from the instance model' do
          instance_plan = InstancePlanFromDB.create_from_instance_model(
            instance_model,
            deployment_plan,
            'started',
            logger,
          )
          expect(instance_plan.instance_model).to eq(instance_model)
        end
      end
    end
  end
end
