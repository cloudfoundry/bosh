require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe InstancePlanFromDB do
      let(:instance_model) do
        FactoryBot.create(:models_instance,
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
      let(:cloud_config_manifest) { SharedSupport::DeploymentManifestHelper.simple_cloud_config }

      let(:deployment_manifest) { SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups }
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
        planner_factory = PlannerFactory.create(per_spec_logger)
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
            per_spec_logger,
          )
          expect(instance_plan.instance_model).to eq(instance_model)
        end
      end

      describe '#spec (TNZ-55033 recovery)' do
        context 'when the persisted spec is missing properties and name' do
          # The default `spec` let block above intentionally omits 'properties' and 'name',
          # simulating an instance left in a partially-applied state after a failed deploy.
          it 'populates name from the instance group so templates can be rendered' do
            instance_plan = InstancePlanFromDB.create_from_instance_model(
              instance_model,
              deployment_plan,
              'started',
              per_spec_logger,
            )
            result = instance_plan.spec
            expect(result.full_spec).to include('name' => 'foobar')
          end

          it 'populates properties from the instance group so templates can be rendered' do
            instance_plan = InstancePlanFromDB.create_from_instance_model(
              instance_model,
              deployment_plan,
              'started',
              per_spec_logger,
            )
            result = instance_plan.spec
            expect(result.full_spec).to have_key('properties')
          end

          it 'calls bind_properties on the instance group when properties is nil' do
            # The isolated (Jobs::UpdateInstance) path never runs the full assembler
            # pipeline, so instance_group.properties is nil; verify bind_properties is
            # invoked to populate it before the repair assignment.
            instance_plan = InstancePlanFromDB.create_from_instance_model(
              instance_model,
              deployment_plan,
              'started',
              per_spec_logger,
            )
            ig = instance_plan.desired_instance.instance_group
            # Stub properties to return nil on first call (simulating unbound state),
            # then return a manifest hash after bind_properties runs.
            allow(ig).to receive(:properties).and_return(nil, { 'prop' => 'val' })
            expect(ig).to receive(:bind_properties)
            instance_plan.spec
          end
        end

        context 'when the persisted spec already has properties and name' do
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
              'name' => 'existing-name',
              'properties' => { 'existing' => 'value' },
            }
          end

          it 'does not overwrite the existing name' do
            instance_plan = InstancePlanFromDB.create_from_instance_model(
              instance_model,
              deployment_plan,
              'started',
              per_spec_logger,
            )
            result = instance_plan.spec
            expect(result.full_spec['name']).to eq('existing-name')
          end

          it 'does not overwrite the existing properties' do
            instance_plan = InstancePlanFromDB.create_from_instance_model(
              instance_model,
              deployment_plan,
              'started',
              per_spec_logger,
            )
            result = instance_plan.spec
            expect(result.full_spec['properties']).to eq('existing' => 'value')
          end
        end
      end
    end
  end
end
