require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe Planner do
      subject(:planner) do
        described_class.new(
          planner_attributes,
          minimal_manifest,
          YAML.dump(minimal_manifest),
          cloud_configs,
          runtime_config_consolidator,
          deployment_model,
          options,
        )
      end

      let(:options) { {} }
      let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }
      let(:cloud_configs) { [] }
      let(:runtime_config_consolidator) { instance_double(Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator) }
      let(:manifest_text) { generate_manifest_text }
      let(:planner_attributes) { { name: 'mycloud', properties: {} } }
      let(:deployment_model) { Models::Deployment.make }

      def generate_manifest_text
        YAML.dump minimal_manifest
      end

      let(:minimal_manifest) do
        {
          'name' => 'minimal',

          'releases' => [{
            'name' => 'appcloud',
            'version' => '0.1' # It's our dummy valid release from spec/assets/valid_release.tgz
          }],

          'networks' => [{
            'name' => 'a',
            'subnets' => [],
          }],

          'compilation' => {
            'workers' => 1,
            'network' => 'a',
            'cloud_properties' => {},
          },

          'resource_pools' => [],

          'update' => {
            'canaries' => 2,
            'canary_watch_time' => 4000,
            'max_in_flight' => 1,
            'update_watch_time' => 20,
          },
        }
      end

      describe 'with invalid options' do
        it 'raises an error if name are not given' do
          planner_attributes.delete(:name)

          expect do
            planner
          end.to raise_error KeyError
        end
      end

      its(:model) { deployment_model }

      describe 'with valid options' do
        let(:stemcell_model) { Bosh::Director::Models::Stemcell.create(name: 'default', version: '1', cid: 'abc') }
        let(:resource_pool_spec) do
          {
            'name' => 'default',
            'cloud_properties' => {},
            'network' => 'default',
            'stemcell' => {
              'name' => 'default',
              'version' => '1',
            },
          }
        end
        let(:resource_pools) { [ResourcePool.new(resource_pool_spec)] }
        let(:vm_type) { VmType.new('name' => 'vm_type') }

        before do
          deployment_model.add_stemcell(stemcell_model)
          deployment_model.add_variable_set(Models::VariableSet.make(deployment: deployment_model))
          cloud_planner = CloudPlanner.new(
            networks: [Network.new('default', logger)],
            global_network_resolver: GlobalNetworkResolver.new(planner, [], logger),
            ip_provider_factory: IpProviderFactory.new(true, logger),
            disk_types: [],
            availability_zones_list: {},
            vm_type: vm_type,
            resource_pools: resource_pools,
            compilation: nil,
            logger: logger,
          )
          planner.cloud_planner = cloud_planner
          allow(Config).to receive_message_chain(:current_job, :username).and_return('username')
          task = Models::Task.make(state: 'processing')
          allow(Config).to receive_message_chain(:current_job, :task_id).and_return(task.id)
        end

        it 'manifest should be immutable' do
          subject = Planner.new(
            planner_attributes,
            minimal_manifest,
            YAML.dump(minimal_manifest),
            cloud_configs,
            runtime_config_consolidator,
            deployment_model,
            options,
          )
          minimal_manifest['name'] = 'new_name'
          expect(subject.uninterpolated_manifest_hash['name']).to eq('minimal')
        end

        it 'should parse recreate' do
          expect(planner.recreate).to be_falsey

          plan = described_class.new(
            planner_attributes,
            manifest_text,
            YAML.dump(manifest_text),
            cloud_configs,
            runtime_config_consolidator,
            deployment_model,
            'recreate' => true,
          )
          expect(plan.recreate).to be_truthy
        end

        it 'creates a vm requirements cache' do
          expect(planner.vm_resources_cache).to be_instance_of(VmResourcesCache)
        end

        describe '#instance_plans_with_hot_swap_and_needs_duplicate_vm' do
          before { subject.add_instance_group(instance_group) }
          let(:instance_plan) { instance_double(InstancePlan) }
          let(:should_hot_swap?) { true }
          let(:instance_group) do
            instance_double(
              'Bosh::Director::DeploymentPlan::InstanceGroup',
              name: 'fake-job1-name',
              canonical_name: 'fake-job1-cname',
              service?: true,
              errand?: false,
              should_hot_swap?: should_hot_swap?,
              unignored_instance_plans_needing_duplicate_vm: [instance_plan],
            )
          end

          it 'should return instance groups that are duplicate-and-replace-vm enabled' do
            expect(subject.instance_plans_with_hot_swap_and_needs_duplicate_vm).to eq([instance_plan])
          end

          context 'when no instance groups have duplicate-and-replace-vm enabled' do
            let(:should_hot_swap?) { false }

            it 'should return empty array' do
              expect(subject.instance_plans_with_hot_swap_and_needs_duplicate_vm).to be_empty
            end
          end
        end

        describe '#skipped_instance_plans_with_hot_swap_and_needs_duplicate_vm' do
          before { subject.add_instance_group(instance_group) }
          let(:instance_plan) { instance_double(InstancePlan) }
          let(:should_hot_swap?) { false }
          let(:hot_swap?) { true }
          let(:instance_group) do
            instance_double(
              'Bosh::Director::DeploymentPlan::InstanceGroup',
              name: 'fake-job1-name',
              canonical_name: 'fake-job1-cname',
              service?: true,
              errand?: false,
              should_hot_swap?: should_hot_swap?,
              hot_swap?: hot_swap?,
              unignored_instance_plans_needing_duplicate_vm: [instance_plan],
            )
          end

          it 'returns instances that want duplicate-and-replace-vm but cannot be' do
            expect(subject.skipped_instance_plans_with_hot_swap_and_needs_duplicate_vm).to eq([instance_plan])
          end

          context 'when instance_group does not want duplicate-and-replace-vm' do
            let(:should_hot_swap?) { false }
            let(:hot_swap?) { false }

            it 'should return empty array' do
              expect(subject.skipped_instance_plans_with_hot_swap_and_needs_duplicate_vm).to be_empty
            end
          end

          context 'when instance_group wants duplicate-and-replace-vm and can be' do
            let(:should_hot_swap?) { true }
            let(:hot_swap?) { true }

            it 'should return empty array' do
              expect(subject.skipped_instance_plans_with_hot_swap_and_needs_duplicate_vm).to be_empty
            end
          end
        end

        describe '#deployment_wide_options' do
          let(:options) do
            {
              'fix' => true,
              'tags' => { 'key1' => 'value1' },
              'some_other_option' => 'disappears',
            }
          end

          it 'returns fix and tags values set on planner' do
            expect(subject.deployment_wide_options).to eq(
              fix: true,
              tags: { 'key1' => 'value1' },
            )
          end

          context 'when fix and tag values are not present' do
            let(:options) { {} }

            it 'returns fix: false and empty tags hash' do
              expect(subject.deployment_wide_options).to eq(
                fix: false,
                tags: {},
              )
            end
          end
        end

        describe '#instance_groups_starting_on_deploy' do
          before { subject.add_instance_group(job1) }
          let(:job1) do
            instance_double('Bosh::Director::DeploymentPlan::InstanceGroup',
                            name: 'fake-job1-name',
                            canonical_name: 'fake-job1-cname',
                            service?: true,
                            errand?: false)
          end

          before { subject.add_instance_group(job2) }
          let(:job2) do
            instance_double('Bosh::Director::DeploymentPlan::InstanceGroup',
                            name: 'fake-job2-name',
                            canonical_name: 'fake-job2-cname',
                            lifecycle: 'errand',
                            service?: false,
                            errand?: true)
          end

          context 'with errand running via keep-alive' do
            before do
              allow(job2).to receive(:instances).and_return([
                                                              instance_double('Bosh::Director::DeploymentPlan::Instance',
                                                                              vm_created?: true),
                                                            ])
            end

            it 'returns both the regular job and keep-alive errand' do
              expect(subject.instance_groups_starting_on_deploy).to eq([job1, job2])
            end
          end

          context 'with errand not running' do
            before do
              allow(job2).to receive(:instances).and_return([
                                                              instance_double('Bosh::Director::DeploymentPlan::Instance',
                                                                              vm_created?: false),
                                                            ])
            end

            it 'returns only the regular job' do
              expect(subject.instance_groups_starting_on_deploy).to eq([job1])
            end
          end
        end

        describe '#errand_instance_groups' do
          let(:instance_group_1) do
            instance_double(
              'Bosh::Director::DeploymentPlan::InstanceGroup',
              name: 'fake-instance-group-1-name',
              canonical_name: 'fake-instance-group-1-cname',
              service?: true,
              errand?: false,
            )
          end

          let(:instance_group_2) do
            instance_double(
              'Bosh::Director::DeploymentPlan::InstanceGroup',
              name: 'fake-instance-group-2-name',
              canonical_name: 'fake-instance-group-2-cname',
              service?: false,
              errand?: true,
            )
          end

          let(:instance_group_3) do
            instance_double(
              'Bosh::Director::DeploymentPlan::InstanceGroup',
              name: 'fake-instance-group-3-name',
              canonical_name: 'fake-instance-group-3-cname',
              service?: false,
              errand?: true,
            )
          end

          before do
            subject.add_instance_group(instance_group_1)
            subject.add_instance_group(instance_group_2)
            subject.add_instance_group(instance_group_3)
          end

          it 'return instance groups with errand lifecylce' do
            expect(subject.errand_instance_groups).to match_array([instance_group_2, instance_group_3])
          end
        end

        describe '#use_short_dns_addresses?' do
          context 'when deployment use_short_dns_addresses is defined' do
            context 'when deployment use_short_dns_addresses is TRUE' do
              before do
                subject.set_features(DeploymentFeatures.new(true, true))
              end

              it 'returns TRUE' do
                expect(subject.use_short_dns_addresses?).to be_truthy
              end
            end

            context 'when deployment use_short_dns_addresses is FALSE' do
              before do
                subject.set_features(DeploymentFeatures.new(true, false))
              end

              it 'returns FALSE' do
                expect(subject.use_short_dns_addresses?).to be_falsey
              end
            end
          end

          context 'when deployment use_short_dns_addresses is NOT defined' do
            before do
              subject.set_features(DeploymentFeatures.new)
            end

            it 'returns FALSE' do
              expect(subject.use_short_dns_addresses?).to be_falsey
            end
          end
        end

        describe '#use_dns_addresses?' do
          context 'when director use_dns_addresses flag is TRUE' do
            before do
              allow(Bosh::Director::Config).to receive(:local_dns_use_dns_addresses?).and_return(true)
            end

            context 'when deployment use_dns_addresses is defined' do
              context 'when deployment use_dns_addresses is TRUE' do
                before do
                  subject.set_features(DeploymentFeatures.new(true))
                end

                it 'returns TRUE' do
                  expect(subject.use_dns_addresses?).to be_truthy
                end
              end

              context 'when deployment use_dns_addresses is FALSE' do
                before do
                  subject.set_features(DeploymentFeatures.new(false))
                end

                it 'returns FALSE' do
                  expect(subject.use_dns_addresses?).to be_falsey
                end
              end
            end

            context 'when deployment use_dns_addresses is NOT defined' do
              before do
                subject.set_features(DeploymentFeatures.new)
              end

              it 'returns TRUE' do
                expect(subject.use_dns_addresses?).to be_truthy
              end
            end
          end

          context 'when director use_dns_addresses flag is FALSE' do
            before do
              allow(Bosh::Director::Config).to receive(:local_dns_use_dns_addresses?).and_return(false)
            end

            context 'when deployment use_dns_addresses is defined' do
              context 'when deployment use_dns_addresses is TRUE' do
                before do
                  subject.set_features(DeploymentFeatures.new(true))
                end

                it 'returns TRUE' do
                  expect(subject.use_dns_addresses?).to be_truthy
                end
              end

              context 'when deployment use_dns_addresses is FALSE' do
                before do
                  subject.set_features(DeploymentFeatures.new(false))
                end

                it 'returns FALSE' do
                  expect(subject.use_dns_addresses?).to be_falsey
                end
              end
            end

            context 'when deployment use_dns_addresses is NOT defined' do
              before do
                subject.set_features(DeploymentFeatures.new)
              end

              it 'returns FALSE' do
                expect(subject.use_dns_addresses?).to be_falsey
              end
            end
          end
        end

        describe '#using_global_networking?' do
          context 'when cloud configs are empty' do
            it 'returns false' do
              expect(subject.using_global_networking?).to be_falsey
            end
          end

          context 'when cloud configs are not empty' do
            let(:cloud_configs) do
              [
                Models::Config.make(
                  :cloud,
                  content: \
                    '--- {"networks":[{"name":"test","subnets":[]}],'\
                    '"compilation":{"workers":1,"canary_watch_time":1,'\
                    '"update_watch_time":1,"serial":false,"network":"test"}}',
                ),
              ]
            end

            it 'returns true' do
              expect(subject.using_global_networking?).to be_truthy
            end
          end
        end

        describe '#randomize_az_placement?' do
          context 'when deployment randomize_az_placement is defined' do
            context 'when deployment randomize_az_placement is TRUE' do
              before do
                subject.set_features(DeploymentFeatures.new(true, true, true))
              end

              it 'returns TRUE' do
                expect(subject.randomize_az_placement?).to be_truthy
              end
            end

            context 'when deployment randomize_az_placement is FALSE' do
              before do
                subject.set_features(DeploymentFeatures.new(true, false, false))
              end

              it 'returns FALSE' do
                expect(subject.randomize_az_placement?).to be_falsey
              end
            end
          end

          context 'when deployment randomize_az_placement is NOT defined' do
            before do
              subject.set_features(DeploymentFeatures.new)
            end

            it 'returns FALSE' do
              expect(subject.randomize_az_placement?).to be_falsey
            end
          end
        end

        describe '#team_names' do
          let(:teams) do
            Bosh::Director::Models::Team.transform_admin_team_scope_to_teams(
              ['bosh.teams.team_1.admin', 'bosh.teams.team_3.admin'],
            )
          end
          before { deployment_model.teams = teams }

          it 'returns team names from the deployment' do
            expect(subject.team_names).to match_array(%w[team_1 team_3])
          end
        end

        context 'links' do
          describe '#add_link_providers' do
            let(:link_provider) { instance_double(Models::LinkProvider) }
            before do
              subject.add_link_provider link_provider
            end
            it 'adds link provider to list of providers' do
              expect(subject.link_providers.count).to eq(1)
              expect(subject.link_providers[0]).to eq(link_provider)
            end
          end

          describe '#add_link_consumers' do
            let(:link_consumer) { instance_double(Models::LinkConsumer) }
            before do
              subject.add_link_consumer link_consumer
            end
            it 'adds link consumer to list of consumers' do
              expect(subject.link_consumers.count).to eq(1)
              expect(subject.link_consumers[0]).to eq(link_consumer)
            end
          end
        end
      end
    end
  end
end
