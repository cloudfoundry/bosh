require 'spec_helper'
require 'ipaddr'

module Bosh::Director
  module DeploymentPlan
    describe InstancePlanFactory do
      include Bosh::Director::IpUtil

      let(:instance_repo) { Bosh::Director::DeploymentPlan::InstanceRepository.new(per_spec_logger, variables_interpolator) }
      let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }
      let(:skip_drain) { SkipDrain.new(true) }
      let(:index_assigner) { instance_double('Bosh::Director::DeploymentPlan::PlacementPlanner::IndexAssigner') }
      let(:existing_instance_model) do
        FactoryBot.create(:models_instance,
                          deployment: deployment_model,
                          job: 'foobar',
                          index: 0,
                          spec: spec,
        ).tap do |i|
          FactoryBot.create(:models_vm, cid: 'vm-cid', instance: i, active: true)
        end
      end

      let(:spec) do
        {
          'vm_type' => {
            'name' => 'vm-type',
            'cloud_properties' => { 'foo' => 'bar' },
          },
          'stemcell' => {
            'name' => 'stemcell-name',
            'version' => '3.0.2',
          },
          'env' => {
            'key1' => 'value1',
          },
          'networks' => {
            'ip' => '192.168.1.1',
          },
        }
      end

      let(:deployment_model) do
        FactoryBot.create(:models_deployment, manifest: YAML.dump(SharedSupport::DeploymentManifestHelper.minimal_manifest))
      end

      let(:range) { IPAddr.new('192.168.1.1/24') }
      let(:manual_network_subnet) { ManualNetworkSubnet.new('name-7', range, nil, nil, nil, nil, nil, [], []) }
      let(:network) { Bosh::Director::DeploymentPlan::ManualNetwork.new('name-7', [manual_network_subnet], per_spec_logger) }
      let(:ip_repo) { Bosh::Director::DeploymentPlan::IpRepo.new(per_spec_logger) }
      let(:deployment_plan) do
        instance_double(
          Planner,
          network: network,
          networks: [network],
          ip_provider: Bosh::Director::DeploymentPlan::IpProvider.new(ip_repo, { 'name-7' => network }, per_spec_logger),
          model: deployment_model,
          skip_drain: skip_drain,
        )
      end
      let(:desired_instance) do
        instance_double('Bosh::Director::DeploymentPlan::DesiredInstance')
      end
      let(:instance_group) do
        instance_double('Bosh::Director::DeploymentPlan::InstanceGroup')
      end

      let(:plan_instance) do
        instance_double('Bosh::Director::DeploymentPlan::Instance')
      end

      let(:states_by_existing_instance) do
        {
          existing_instance_model =>
            {
              'networks' =>
                {
                  'name-7' => {
                    'ip' => '192.168.1.1',
                    'type' => 'dynamic',
                  },
                },
            },
        }
      end
      let(:options) { {} }

      subject(:instance_plan_factory) do
        InstancePlanFactory.new(
          instance_repo,
          states_by_existing_instance,
          deployment_plan,
          index_assigner,
          variables_interpolator,
          link_provider_intents,
          options,
        )
      end

      let(:link_provider_intents) { [] }

      before do
        FactoryBot.create(:models_stemcell, name: 'stemcell-name', version: '3.0.2', cid: 'sc-302')
        allow(desired_instance).to receive(:instance_group).and_return(instance_group)
        allow(desired_instance).to receive(:index).and_return(1)
        allow(desired_instance).to receive(:index=)
        allow(desired_instance).to receive(:deployment)
        allow(instance_repo).to receive(:create)
        allow(instance_repo).to receive(:fetch_existing).and_return(plan_instance)
        allow(instance_group).to receive(:name).and_return('group-name')
        allow(index_assigner).to receive(:assign_index)
        allow(plan_instance).to receive(:update_description)
        Bosh::Director::Config.current_job = Bosh::Director::Jobs::BaseJob.new
        Bosh::Director::Config.current_job.task_id = 'fake-task-id'
      end

      describe '#obsolete_instance_plan' do
        it 'returns an instance plan with a nil desired instance' do
          instance_plan = instance_plan_factory.obsolete_instance_plan(existing_instance_model)
          expect(instance_plan.desired_instance).to be_nil
        end

        it 'populates the instance plan existing model' do
          instance_plan = instance_plan_factory.obsolete_instance_plan(existing_instance_model)
          expect(instance_plan.existing_instance).to eq(existing_instance_model)
        end

        context 'use_dns_addresses' do
          let(:existing_instance_model) do
            FactoryBot.create(:models_instance,
                              deployment: deployment_model,
                              job: 'foobar',
                              index: 0,
                              spec: spec,
                              variable_set: variable_set,
            ).tap do |i|
              FactoryBot.create(:models_vm, cid: 'vm-cid', instance: i, active: true)
            end
          end

          context 'when passed as TRUE in the options' do
            let(:options) { { 'use_dns_addresses' => true } }
            let(:variable_set) { FactoryBot.create(:models_variable_set, deployment: deployment_model) }

            it 'provides the instance_plan with the correct use_dns_addresses' do
              expect(InstancePlan).to receive(:new).with(
                desired_instance: anything,
                existing_instance: anything,
                instance: anything,
                skip_drain: anything,
                recreate_deployment: anything,
                use_dns_addresses: true,
                use_short_dns_addresses: false,
                use_link_dns_addresses: false,
                variables_interpolator: variables_interpolator,
                link_provider_intents: [],
              )
              instance_plan_factory.obsolete_instance_plan(existing_instance_model)
            end

            context 'when also passing use_short_dns_addresses' do
              let(:options) { { 'use_short_dns_addresses' => true, 'use_dns_addresses' => true } }
              it 'provides the instance_plan with the correct use_dns_addresses' do
                expect(InstancePlan).to receive(:new).with(
                  desired_instance: anything,
                  existing_instance: anything,
                  instance: anything,
                  skip_drain: anything,
                  recreate_deployment: anything,
                  use_dns_addresses: true,
                  use_short_dns_addresses: true,
                  use_link_dns_addresses: false,
                  variables_interpolator: variables_interpolator,
                  link_provider_intents: [],
                )
                instance_plan_factory.obsolete_instance_plan(existing_instance_model)
              end
            end
          end

          context 'when passed as FALSE in the options' do
            let(:options) { { 'use_dns_addresses' => false } }
            let(:variable_set) { FactoryBot.create(:models_variable_set, deployment: deployment_model) }

            it 'provides the instance_plan with the correct use_dns_addresses' do
              expect(InstancePlan).to receive(:new).with(
                desired_instance: anything,
                existing_instance: anything,
                instance: anything,
                skip_drain: anything,
                recreate_deployment: anything,
                use_short_dns_addresses: false,
                use_dns_addresses: false,
                use_link_dns_addresses: false,
                variables_interpolator: variables_interpolator,
                link_provider_intents: [],
              )
              instance_plan_factory.obsolete_instance_plan(existing_instance_model)
            end
          end
        end

        context 'randomize_az_placement' do
          let(:existing_instance_model) do
            FactoryBot.create(:models_instance,
                              deployment: deployment_model,
                              job: 'foobar',
                              index: 0,
                              spec: spec,
                              variable_set: variable_set,
            ).tap do |i|
              FactoryBot.create(:models_vm, cid: 'vm-cid', instance: i, active: true)
            end
          end

          let(:variable_set) { FactoryBot.create(:models_variable_set, deployment: deployment_model) }

          context 'when passed as TRUE in the options' do
            let(:options) { { 'randomize_az_placement' => true } }

            it 'knows whether to randomize az placement' do
              expect(instance_plan_factory.randomize_az_placement?).to be(true)
            end
          end

          context 'when passed as FALSE in the options' do
            let(:options) { { 'randomize_az_placement' => false } }

            it 'knows whether to randomize az placement' do
              expect(instance_plan_factory.randomize_az_placement?).to be(false)
            end
          end
        end

        context 'when there are link provider intents' do
          let(:link_provider_intents) { double(:link_provider_intents) }

          it 'passes them when creating an instance plan' do
            expect(InstancePlan).to receive(:new).with(
              include(
                link_provider_intents: link_provider_intents,
              ),
            )
            instance_plan_factory.obsolete_instance_plan(existing_instance_model)
          end
        end
      end

      describe '#desired_existing_instance_plan' do
        let(:tags) { { 'key1' => 'value1' } }
        let(:options) { { 'tags' => tags } }

        it 'passes tags to instance plan creation' do
          expect(InstancePlan).to receive(:new).with(
            desired_instance: anything,
            existing_instance: anything,
            instance: anything,
            skip_drain: anything,
            recreate_deployment: anything,
            recreate_persistent_disks: anything,
            use_dns_addresses: anything,
            use_short_dns_addresses: anything,
            use_link_dns_addresses: anything,
            tags: tags,
            variables_interpolator: variables_interpolator,
            link_provider_intents: [],
          )

          instance_plan_factory.desired_existing_instance_plan(existing_instance_model, desired_instance)
        end

        context 'recreate_persistent_disks' do
          let(:options) { { 'recreate_persistent_disks' => true } }

          it 'provides the instance_plan with the correct recreate_persistent_disks' do
            expect(InstancePlan).to receive(:new).with(
              desired_instance: anything,
              existing_instance: anything,
              instance: anything,
              skip_drain: anything,
              recreate_deployment: anything,
              recreate_persistent_disks: true,
              tags: anything,
              use_dns_addresses: anything,
              use_short_dns_addresses: anything,
              use_link_dns_addresses: anything,
              variables_interpolator: anything,
              link_provider_intents: [],
            )
            instance_plan_factory.desired_existing_instance_plan(existing_instance_model, desired_instance)
          end
        end

        context 'use_dns_addresses' do
          let(:existing_instance_model) do
            FactoryBot.create(:models_instance,
                              deployment: deployment_model,
                              job: 'foobar',
                              index: 0,
                              spec: spec,
                              variable_set: variable_set,
            ).tap do |i|
              FactoryBot.create(:models_vm, cid: 'vm-cid', instance: i, active: true)
            end
          end

          context 'when passed as TRUE in the options' do
            let(:options) { { 'use_dns_addresses' => true } }
            let(:variable_set) { FactoryBot.create(:models_variable_set, deployment: deployment_model) }

            it 'provides the instance_plan with the correct use_dns_addresses' do
              expect(InstancePlan).to receive(:new).with(
                desired_instance: anything,
                existing_instance: anything,
                instance: anything,
                skip_drain: anything,
                recreate_deployment: anything,
                recreate_persistent_disks: anything,
                tags: anything,
                use_dns_addresses: true,
                use_short_dns_addresses: false,
                use_link_dns_addresses: false,
                variables_interpolator: variables_interpolator,
                link_provider_intents: [],
              )
              instance_plan_factory.desired_existing_instance_plan(existing_instance_model, desired_instance)
            end

            context 'when also passing use_short_dns_addresses' do
              let(:options) { { 'use_short_dns_addresses' => true, 'use_dns_addresses' => true } }
              it 'provides the instance_plan with the correct use_dns_addresses' do
                expect(InstancePlan).to receive(:new).with(
                  desired_instance: anything,
                  existing_instance: anything,
                  instance: anything,
                  skip_drain: anything,
                  recreate_deployment: anything,
                  use_dns_addresses: true,
                  use_short_dns_addresses: true,
                  use_link_dns_addresses: false,
                  variables_interpolator: anything,
                  link_provider_intents: [],
                )
                instance_plan_factory.obsolete_instance_plan(existing_instance_model)
              end
            end
          end

          context 'when passed as FALSE in the options' do
            let(:options) { { 'use_dns_addresses' => false } }
            let(:variable_set) { FactoryBot.create(:models_variable_set, deployment: deployment_model) }

            it 'provides the instance_plan with the correct use_dns_addresses' do
              expect(InstancePlan).to receive(:new).with(
                desired_instance: anything,
                existing_instance: anything,
                instance: anything,
                skip_drain: anything,
                recreate_deployment: anything,
                recreate_persistent_disks: anything,
                tags: anything,
                use_dns_addresses: false,
                use_short_dns_addresses: false,
                use_link_dns_addresses: false,
                variables_interpolator: anything,
                link_provider_intents: [],
              )
              instance_plan_factory.desired_existing_instance_plan(existing_instance_model, desired_instance)
            end
          end
        end

        context 'when there are link provider intents' do
          let(:link_provider_intents) { double(:link_provider_intents) }

          it 'passes them when creating an instance plan' do
            expect(InstancePlan).to receive(:new).with(
              include(
                link_provider_intents: link_provider_intents,
              ),
            )
            instance_plan_factory.desired_existing_instance_plan(existing_instance_model, desired_instance)
          end
        end
      end

      describe '#desired_new_instance_plan' do
        let(:tags) { { 'key1' => 'value1' } }
        let(:options) { { 'tags' => tags } }

        it 'passes tags to instance plan creation' do
          expect(InstancePlan).to receive(:new).with(
            desired_instance: anything,
            existing_instance: anything,
            instance: anything,
            skip_drain: anything,
            recreate_deployment: anything,
            use_short_dns_addresses: anything,
            use_dns_addresses: anything,
            use_link_dns_addresses: anything,
            tags: tags,
            variables_interpolator: anything,
            link_provider_intents: [],
          )

          instance_plan_factory.desired_new_instance_plan(desired_instance)
        end

        context 'use_dns_addresses' do
          let(:existing_instance_model) do
            FactoryBot.create(:models_instance,
                              deployment: deployment_model,
                              job: 'foobar',
                              index: 0,
                              spec: spec,
                              variable_set: variable_set,
            ).tap do |i|
              FactoryBot.create(:models_vm, cid: 'vm-cid', instance: i, active: true)
            end
          end

          context 'when passed as TRUE in the options' do
            let(:options) { { 'use_dns_addresses' => true } }
            let(:variable_set) { FactoryBot.create(:models_variable_set, deployment: deployment_model) }

            it 'provides the instance_plan with the correct use_dns_addresses' do
              expect(InstancePlan).to receive(:new).with(
                desired_instance: anything,
                existing_instance: anything,
                instance: anything,
                skip_drain: anything,
                recreate_deployment: anything,
                tags: anything,
                use_dns_addresses: true,
                use_short_dns_addresses: false,
                use_link_dns_addresses: false,
                variables_interpolator: anything,
                link_provider_intents: [],
              )
              instance_plan_factory.desired_new_instance_plan(desired_instance)
            end

            context 'when also passing use_short_dns_addresses' do
              let(:options) { { 'use_short_dns_addresses' => true, 'use_dns_addresses' => true } }
              it 'provides the instance_plan with the correct use_dns_addresses' do
                expect(InstancePlan).to receive(:new).with(
                  desired_instance: anything,
                  existing_instance: anything,
                  instance: anything,
                  skip_drain: anything,
                  recreate_deployment: anything,
                  use_dns_addresses: true,
                  use_short_dns_addresses: true,
                  use_link_dns_addresses: false,
                  variables_interpolator: anything,
                  link_provider_intents: [],
                )
                instance_plan_factory.obsolete_instance_plan(existing_instance_model)
              end
            end
          end

          context 'when passed as FALSE in the options' do
            let(:options) { { 'use_dns_addresses' => false } }
            let(:variable_set) { FactoryBot.create(:models_variable_set, deployment: deployment_model) }

            it 'provides the instance_plan with the correct use_dns_addresses' do
              expect(InstancePlan).to receive(:new).with(
                desired_instance: anything,
                existing_instance: anything,
                instance: anything,
                skip_drain: anything,
                recreate_deployment: anything,
                tags: anything,
                use_dns_addresses: false,
                use_short_dns_addresses: false,
                use_link_dns_addresses: false,
                variables_interpolator: anything,
                link_provider_intents: [],
              )
              instance_plan_factory.desired_new_instance_plan(desired_instance)
            end
          end
        end

        context 'when there are link provider intents' do
          let(:link_provider_intents) { double(:link_provider_intents) }

          it 'passes them when creating an instance plan' do
            expect(InstancePlan).to receive(:new).with(
              include(
                link_provider_intents: link_provider_intents,
              ),
            )
            instance_plan_factory.desired_new_instance_plan(desired_instance)
          end
        end
      end
    end
  end
end
