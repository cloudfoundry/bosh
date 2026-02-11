require 'spec_helper'

module Bosh::Director
  module Jobs
    describe UpdateDeployment do
      subject(:job) do
        UpdateDeployment.new(manifest_content, cloud_config_id, runtime_config_ids, options).tap do |obj|
          allow(obj).to receive(:task_id).and_return(task.id)
        end
      end

      let(:config) { Config.load_hash(SpecHelper.director_config_hash) }
      let(:directory) { Support::FileHelpers::DeploymentDirectory.new }
      let(:manifest_content) { YAML.dump(SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups) }
      let(:cloud_config_id) { nil }
      let(:runtime_config_ids) { [] }
      let(:options) { {} }
      let(:networks) { nil }

      let(:deployment_instance_group) do
        FactoryBot.build(:deployment_plan_instance_group, networks: networks)
      end

      let(:errand_instance_group) do
        FactoryBot.build(:deployment_plan_instance_group, name: 'some-errand-instance-group')
      end

      let(:task) { FactoryBot.create(:models_task, id: 42, username: 'user') }
      let(:availability_zones) { [zone_1, zone_2] }
      let(:zone_1) { DeploymentPlan::AvailabilityZone.new('zone_1', {}) }
      let(:zone_2) { DeploymentPlan::AvailabilityZone.new('zone_2', {}) }
      let(:logger) { instance_double(Logging::Logger) }
      let(:dns_encoder) { instance_double(DnsEncoder) }
      let(:resolved_links) { [] }
      let(:links_manager) do
        instance_double(Bosh::Director::Links::LinksManager).tap do |double|
          allow(double).to receive(:get_links_for_instance_group).and_return(resolved_links)
        end
      end
      let(:deployment_name) { SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups['name'] }

      before do
        App.new(config)
        allow(Bosh::Director::Links::LinksManager).to receive(:new).and_return(links_manager)
        allow(Time).to receive_messages(now: Time.parse('2016-02-15T09:55:40Z'))
      end

      describe '#perform' do
        let(:compile_stage) { instance_double(DeploymentPlan::Stages::PackageCompileStage) }
        let(:update_stage) { instance_double(DeploymentPlan::Stages::UpdateStage) }
        let(:create_network_stage) do
          instance_double(DeploymentPlan::Stages::CreateNetworkStage, perform: true)
        end
        let(:notifier) { instance_double(DeploymentPlan::Notifier) }
        let(:template_blob_cache) { instance_double(Bosh::Director::Core::Templates::TemplateBlobCache) }
        let(:variables_interpolator) { instance_double(ConfigServer::VariablesInterpolator, interpolate_with_versioning: nil) }
        let(:planner_factory) do
          instance_double(
            DeploymentPlan::PlannerFactory,
            create_from_manifest: planner,
          )
        end
        let(:deployment_model) { FactoryBot.create(:models_deployment, name: deployment_name, manifest: '{}') }
        let(:planner) do
          instance_double(
            DeploymentPlan::Planner,
            name: deployment_name,
            instance_groups: [deployment_instance_group],
            instance_groups_starting_on_deploy: [deployment_instance_group],
            errand_instance_groups: [errand_instance_group],
            template_blob_cache: template_blob_cache,
            availability_zones: availability_zones,
            model: deployment_model,
            link_provider_intents: [],
            stemcells: {},
            recreate_vms_created_before: nil,
          )
        end
        let(:assembler) { instance_double(DeploymentPlan::Assembler, bind_models: nil) }
        let(:variable_set) { FactoryBot.create(:models_variable_set, deployment: deployment_model) }

        before do
          allow(LocalDnsEncoderManager).to receive(:new_encoder_with_updated_index).with(planner).and_return(dns_encoder)
          allow(DeploymentPlan::Stages::PackageCompileStage).to receive(:create).with(planner).and_return(compile_stage)
          allow(DeploymentPlan::Stages::UpdateStage).to receive(:new).and_return(update_stage)
          allow(DeploymentPlan::Stages::CreateNetworkStage).to receive(:new)
            .with(Config.logger, planner).and_return(create_network_stage)
          allow(DeploymentPlan::Notifier).to receive(:new).and_return(notifier)
          allow(ConfigServer::VariablesInterpolator).to receive(:new).and_return(variables_interpolator)
          allow(DeploymentPlan::PlannerFactory).to receive(:new).and_return(planner_factory)
          allow(planner).to receive(:variables).and_return(DeploymentPlan::Variables.new([]))
          allow(planner).to receive(:features).and_return(DeploymentPlan::DeploymentFeatures.new)
          allow(variables_interpolator).to receive(:interpolate_template_spec_properties) { |properties, _| properties }
          allow(variables_interpolator).to receive(:interpolate_link_spec_properties) { |links_spec| links_spec }
          allow(variables_interpolator).to receive(:interpolate_deployment_manifest) { |manifest| manifest }
          allow(deployment_model).to receive(:current_variable_set).and_return(variable_set)
          allow(template_blob_cache).to receive(:clean_cache!)
          allow(DeploymentPlan::Assembler).to receive(:create).and_return(assembler)
          allow(JobRenderer).to receive(:render_job_instances_with_cache).with(
            anything,
            anything,
            template_blob_cache,
            dns_encoder,
            planner.link_provider_intents,
          )
          allow(job).to receive(:with_deployment_lock).and_yield
        end

        context 'when variables need to be interpolated from config server' do
          before do
            allow(compile_stage).to receive(:perform)
            allow(update_stage).to receive(:perform)
            allow(planner).to receive(:instance_models).and_return([])
            allow(planner).to receive(:instance_groups).and_return([deployment_instance_group])
            allow(notifier).to receive(:send_start_event)
            allow(notifier).to receive(:send_end_event)
          end

          context "when it is a 'deploy' action" do
            let(:options) do
              { 'deploy' => true }
            end
            let(:fixed_time) { Time.now }
            let(:instance_plan1) {instance_double(Bosh::Director::DeploymentPlan::InstancePlan)}
            let(:instance_plan2) {instance_double(Bosh::Director::DeploymentPlan::InstancePlan)}
            let(:instance_plans) { [instance_plan1, instance_plan2] }
            let(:instance1) { instance_double(Bosh::Director::DeploymentPlan::Instance)}
            let(:instance2) { instance_double(Bosh::Director::DeploymentPlan::Instance)}

            let(:manifest) { instance_double( Bosh::Director::Manifest)}

            let(:client_factory) { instance_double(ConfigServer::ClientFactory) }
            let(:config_server_client) { instance_double(ConfigServer::ConfigServerClient) }

            before do
              allow(ConfigServer::ClientFactory).to receive(:create).and_return(client_factory)
              allow(client_factory).to receive(:create_client).and_return(config_server_client)
              allow(config_server_client).to receive(:generate_values)

              allow(Models::Deployment).to receive(:find).with(name: deployment_name).and_return(deployment_model)
              allow(Time).to receive(:now).and_return(fixed_time)
              allow(deployment_model).to receive(:add_variable_set)
              allow(links_manager).to receive(:remove_unused_links)

              allow(Bosh::Director::Manifest).to receive(:load_from_hash).and_return(manifest)

              allow(deployment_instance_group).to receive(:unignored_instance_plans).and_return(instance_plans)
              allow(deployment_instance_group).to receive(:referenced_variable_sets).and_return([])

              allow(instance_plan1).to receive(:instance).and_return(instance1)
              allow(instance_plan2).to receive(:instance).and_return(instance2)
              allow(JobRenderer).to receive(:render_job_instances_with_cache).with(
                anything, # logger
                deployment_instance_group.unignored_instance_plans,
                template_blob_cache,
                dns_encoder,
                planner.link_provider_intents,
              )
            end

            it 'should create a new variable set for the deployment and mark variable sets' do
              expect(deployment_model).to receive(:add_variable_set).with(
                created_at: fixed_time,
                writable: true,
              )
              expect do
                job.perform
              end.to change { deployment_model.links_serial_id }.by(1)
            end

            it "should set the VariableSet's deployed_successfully field" do
              expect(variable_set).to receive(:update).with(:deployed_successfully => true)
              job.perform
            end

            it 'should perform links cleanup' do
              expect(links_manager).to receive(:remove_unused_links).with(deployment_model)
              job.perform
            end

            it 'cleans up old VariableSets' do
              another_variable_set =  FactoryBot.create(:models_variable_set, deployment: deployment_model)
              allow(deployment_instance_group).to receive(:referenced_variable_sets).and_return([variable_set, another_variable_set])

              expect(deployment_model).to receive(:cleanup_variable_sets).with([variable_set, another_variable_set])
              job.perform
            end

            context 'when network lifecycle is enabled' do
              before do
                allow(Config).to receive(:network_lifecycle_enabled?).and_return true
                allow(deployment_model).to receive(:networks).and_return [
                  inuse,
                  unmanaged,
                  orphanable,
                  unorphanable,
                ]
                allow(deployment_model).to receive(:remove_network)
                allow(job).to receive(:with_network_lock) do |&block|
                  block.call
                end
              end

              let(:networks) { instance_group_networks }

              let(:instance_group_networks) do
                [
                  inuse_managed_instance_group_network,
                  unmanaged_instance_group_network,
                ]
              end

              let(:inuse_managed_instance_group_network) do
                instance_double(
                  Bosh::Director::DeploymentPlan::JobNetwork,
                  deployment_network: inuse_deployment_network,
                )
              end

              let(:unmanaged_instance_group_network) do
                instance_double(
                  Bosh::Director::DeploymentPlan::JobNetwork,
                  deployment_network: unmanaged_deployment_network,
                )
              end

              let(:unmanaged_deployment_network) do
                instance_double(
                  Bosh::Director::DeploymentPlan::Network,
                  managed?: false,
                  name: 'unmanaged',
                )
              end

              let(:unmanaged) do
                unmanaged = instance_double(
                  Bosh::Director::Models::Network,
                  name: 'unmanaged',
                  deployments: [],
                )

                allow(unmanaged).to receive(:orphaned=)
                allow(unmanaged).to receive(:orphaned_at=)
                allow(unmanaged).to receive(:save)

                unmanaged
              end

              let(:inuse_deployment_network) do
                instance_double(
                  Bosh::Director::DeploymentPlan::Network,
                  managed?: true,
                  name: 'inuse',
                )
              end

              let(:inuse) do
                inuse = instance_double(
                  Bosh::Director::Models::Network,
                  name: 'inuse',
                )

                allow(inuse).to receive(:orphaned=)
                allow(inuse).to receive(:orphaned_at=)
                allow(inuse).to receive(:save)

                inuse
              end

              let(:orphanable) do
                instance_double(
                  Bosh::Director::DeploymentPlan::Network,
                  managed?: true,
                )
              end

              let(:orphanable) do
                orphanable = instance_double(
                  Bosh::Director::Models::Network,
                  name: 'orphanable',
                  deployments: [],
                )

                allow(orphanable).to receive(:orphaned=)
                allow(orphanable).to receive(:orphaned_at=)
                allow(orphanable).to receive(:save)

                orphanable
              end

              let(:unorphanable_deployment_network) do
                instance_double(
                  Bosh::Director::DeploymentPlan::Network,
                  managed?: true,
                  name: 'unorphanable',
                  deployments: [:something],
                )
              end

              let(:unorphanable) do
                unorphanable = instance_double(
                  Bosh::Director::Models::Network,
                  name: 'unorphanable',
                  deployments: [:something],
                )

                allow(unorphanable).to receive(:orphaned=)
                allow(unorphanable).to receive(:orphaned_at=)
                allow(unorphanable).to receive(:save)

                unorphanable
              end

              it 'cleans up orphaned networks' do
                job.perform

                expect(job).to have_received(:with_network_lock).with('orphanable')
                expect(job).to have_received(:with_network_lock).with('unorphanable')
                expect(job).to have_received(:with_network_lock).with('unmanaged')
                expect(job).to have_received(:with_network_lock).with('inuse')

                expect(deployment_model).to have_received(:remove_network).with(orphanable)
                expect(deployment_model).to have_received(:remove_network).with(unorphanable)
                expect(deployment_model).to have_received(:remove_network).with(unmanaged)
                expect(deployment_model).to_not have_received(:remove_network).with(inuse)

                expect(orphanable).to have_received(:orphaned=).with(true)
                expect(orphanable).to have_received(:orphaned_at=)
                expect(orphanable).to have_received(:save)

                expect(unmanaged).to have_received(:orphaned=)
                expect(unmanaged).to have_received(:orphaned_at=)
                expect(unmanaged).to have_received(:save)

                expect(unorphanable).to_not have_received(:orphaned=)
                expect(unorphanable).to_not have_received(:orphaned_at=)
                expect(unorphanable).to_not have_received(:save)
                expect(inuse).to_not have_received(:orphaned=)
                expect(inuse).to_not have_received(:orphaned_at=)
                expect(inuse).to_not have_received(:save)
              end
            end

            it 'increments links_serial_id in deployment' do
              old_links_serial_id = deployment_model.links_serial_id
              job.perform
              new_links_serial_id = deployment_model.links_serial_id

              expect(new_links_serial_id).to eq(old_links_serial_id + 1)
            end

            it 'does not fail if cleaning up old VariableSets raises an error' do
              another_variable_set =  FactoryBot.create(:models_variable_set, deployment: deployment_model)
              allow(deployment_instance_group).to receive(:referenced_variable_sets).and_return([variable_set, another_variable_set])
              allow(deployment_model).to receive(:cleanup_variable_sets).with([variable_set, another_variable_set]).and_raise(Sequel::ForeignKeyConstraintViolation.new)

              expect {
                job.perform
              }.to_not raise_error
            end

            it 'should bind the models with correct options in the assembler' do
              expect(assembler).to receive(:bind_models).with(
                hash_including({
                  :is_deploy_action => true,
                  :should_bind_new_variable_set => true,
                }),
              )

              job.perform
            end
          end

          context "when options hash does NOT contain 'deploy'" do
            let(:options) do
              { 'deploy' => false }
            end
            let(:manifest) { instance_double( Bosh::Director::Manifest)}

            before do
              allow(Bosh::Director::Manifest).to receive(:load_from_hash).and_return(manifest)
              expect(Models::Deployment).to_not receive(:find).with(name: deployment_name)
            end

            it 'should bind the models with correct options in the assembler' do
              expect(assembler).to receive(:bind_models).with(
                hash_including({
                  :is_deploy_action => false,
                  :should_bind_new_variable_set => false,
                }),
              )

              job.perform
            end

            it 'should not add a new variable set to the deployment model' do
              expect(deployment_model).to_not receive(:add_variable_set)

              expect do
                job.perform
              end.to_not(change { deployment_model.links_serial_id })
            end

            it 'should NOT mark new variable set or remove unused variable sets' do
              expect(variable_set).to_not receive(:update).with(:deployed_successfully => true)

              job.perform
            end

            it 'should not clean up' do
              expect(links_manager).to_not receive(:remove_unused_links)
              expect(deployment_model).to_not receive(:cleanup_variable_sets)

              job.perform
            end

            context 'even when network lifecycle is enabled' do
              before do
                allow(Config).to receive(:network_lifecycle_enabled?).and_return true
              end

              it 'should not clean up the orphaned networks' do
                job.perform
              end
            end
          end

          context 'when the manifest cannot interpolate all the variables' do
            let(:manifest_error) { Exception.new('oh noes!') }

            it 'should not raise when manifest cannot be loaded' do
              expect(Bosh::Director::Manifest).to receive(:load_from_hash).and_raise manifest_error

              expect { job.perform }.to raise_error(manifest_error)
            end
          end

          context 'when the manifest contains YAML anchors' do
            let(:manifest_content) do
              <<~MANIFEST
                ---
                deployment-name: &name-alias 'simple'
                name: *name-alias

                releases:
                - name: test_release
                  version: 1

                stemcells:
                - alias: default
                  os: toronto-os
                  version: latest

                update:
                  canaries: 2
                  canary_watch_time: 4000
                  max_in_flight: 1
                  update_watch_time: 20
              MANIFEST
            end

            let(:cloud_config_id) { ['cloud_config_id'] }
            let(:cloud_configs) do
              [FactoryBot.create(:models_config_cloud, content: YAML.dump('azs' => ['my-az'],
                                                             'vm_types' => ['my-vm-type'],
                                                             'disk_types' => ['my-disk-type'],
                                                             'networks' => ['my-net'],
                                                             'vm_extensions' => ['my-extension']))]
            end

            let(:runtime_config_ids) { ['runtime_config_id'] }
            let(:runtime_configs) { [FactoryBot.create(:models_config_runtime)] }


            it 'should be successfully loaded' do
              allow(Bosh::Director::Models::Config).to receive(:find_by_ids).with(cloud_config_id).and_return(cloud_configs)
              allow(Bosh::Director::Models::Config).to receive(:find_by_ids).with(runtime_config_ids).and_return(runtime_configs)
              allow(variables_interpolator).to receive(:interpolate_cloud_manifest).and_return({})
              allow(variables_interpolator).to receive(:interpolate_runtime_manifest).and_return({})

              job.perform

              expect(planner_factory).to have_received(:create_from_manifest) do |arg1, arg2, arg3, arg4|
                expect(arg1.manifest_hash['name']).to eq('simple')
                expect(arg2).to eq(cloud_configs)
                expect(arg3).to eq(runtime_configs)
                expect(arg4).to eq({})
              end
            end
          end
        end

        context 'when all steps complete' do
          let(:variable_set_1) { instance_double(Bosh::Director::Models::VariableSet, id: 43) }
          let(:manifest) { instance_double( Bosh::Director::Manifest)}

          before do
            expect(notifier).to receive(:send_start_event).ordered
            expect(create_network_stage).to receive(:perform).ordered
            expect(compile_stage).to receive(:perform).ordered
            expect(update_stage).to receive(:perform).ordered
            expect(notifier).to receive(:send_end_event).ordered
            allow(JobRenderer).to receive(:render_job_instances_with_cache)
              .with(logger, anything, template_blob_cache, anything, planner.link_provider_intents)
            allow(planner).to receive(:instance_models).and_return([])
            allow(planner).to receive(:instance_groups).and_return([deployment_instance_group])
            allow(Models::Deployment).to receive(:[]).with(name: deployment_name).and_return(deployment_model)
            allow(deployment_model).to receive(:current_variable_set).and_return(variable_set_1)
            allow(Bosh::Director::Manifest).to receive(:load_from_hash).and_return(manifest)
          end

          it 'binds models, renders templates, compiles packages, runs post-deploy scripts, marks variable_sets' do
            expect(assembler).to receive(:bind_models)
            expect(JobRenderer).to receive(:render_job_instances_with_cache).with(
              anything,
              deployment_instance_group.unignored_instance_plans,
              template_blob_cache,
              anything,
              planner.link_provider_intents,
            )

            job.perform
          end

          it 'should clean job blob cache at the end of the deploy' do
            expect(template_blob_cache).to receive(:clean_cache!)

            job.perform
          end

          context 'errands variables versioning' do
            let(:errand_properties) do
              { 'some-key' => 'some-value' }
            end

            let(:job_1_links) do
              {
                'consumed_link_1' => {
                  'properties' => {
                    'smurf_1'  => '((smurf_placeholder_1))'
                  }
                }
              }
            end

            let(:job_2_links) do
              {
                'consumed_link_2' => {
                  'properties' => {
                    'smurf_2'  => '((smurf_placeholder_2))'
                  }
                }
              }
            end

            let(:resolved_links) do
              {
                'job_1' => job_1_links,
                'job_2' => job_2_links
              }
            end

            before do
              allow(errand_instance_group).to receive(:properties).and_return(errand_properties)
              allow(links_manager).to receive(:get_links_for_instance_group).and_return(resolved_links)
            end

            it 'versions the variables in errands' do
              expect(variables_interpolator).to receive(:interpolate_template_spec_properties).with(errand_properties, deployment_name, errand_instance_group.name, variable_set_1)
              expect(variables_interpolator).to receive(:interpolate_link_spec_properties).with(job_1_links, variable_set_1)
              expect(variables_interpolator).to receive(:interpolate_link_spec_properties).with(job_2_links, variable_set_1)

              job.perform
            end

            it 'versions the links in errands' do
              allow(variables_interpolator).to receive(:interpolate_template_spec_properties).with(errand_properties, deployment_name, errand_instance_group.name, variable_set_1)
              allow(variables_interpolator).to receive(:interpolate_link_spec_properties).with(job_1_links, variable_set_1)
              allow(variables_interpolator).to receive(:interpolate_link_spec_properties).with(job_2_links, variable_set_1)

              instance_1 = instance_double(Bosh::Director::DeploymentPlan::Instance)
              instance_2 = instance_double(Bosh::Director::DeploymentPlan::Instance)
              allow(errand_instance_group).to receive(:instances).and_return([instance_1, instance_2])
              expect(links_manager).to receive(:bind_links_to_instance).with(instance_1)
              expect(links_manager).to receive(:bind_links_to_instance).with(instance_2)

              job.perform
            end
          end

          context 'when there is no cloud_config' do
            it 'passes nil where cloud_config would be passed' do
              expect(job.perform).to eq('/deployments/simple')

              expect(Manifest).to have_received(:load_from_hash)
                .with(anything, anything, Array, anything)
              expect(planner_factory).to have_received(:create_from_manifest)
                .with(anything, Array, anything, anything)
            end
          end

          context 'when a cloud_config is passed in' do
            let(:cloud_config)     { FactoryBot.create(:models_config_cloud) }
            let(:cloud_config_id)  { cloud_config.id }

            it 'uses the cloud config' do
              expect(job.perform).to eq('/deployments/simple')

              expect(Manifest).to have_received(:load_from_hash)
                .with(anything, anything, [cloud_config], anything)
              expect(planner_factory).to have_received(:create_from_manifest)
                .with(anything, [cloud_config], anything, anything)
            end
          end

          context 'when a runtime_config is passed in' do
            let(:runtime_config)     { FactoryBot.create(:models_config_runtime) }
            let(:runtime_config_ids) { [runtime_config.id] }

            before do
              allow(variables_interpolator).to receive(:interpolate_runtime_manifest)
            end

            it 'uses the runtime config' do
              expect(job.perform).to eq('/deployments/simple')

              expect(Manifest).to have_received(:load_from_hash)
                .with(anything, anything, anything, [runtime_config])
              expect(planner_factory).to have_received(:create_from_manifest)
                .with(anything, anything, [runtime_config], anything)
            end
          end

          context 'stemcell change' do
            let(:stemcell1) { FactoryBot.create(:models_stemcell, name: 'ubuntu-alias', operating_system: 'ubuntu-jammy', version: '1.2', cid: 'cid-1') }
            let(:stemcell2) { FactoryBot.create(:models_stemcell, name: 'windows-alias', operating_system: 'windows2019', version: '3.4', cid: 'cid-2') }

            before do
              deployment_model.add_stemcell(stemcell1)
              deployment_model.add_stemcell(stemcell2)
            end

            context 'all stemcell versions have changed and it is not overridden with "force_latest_variables"' do
              before do
                allow(planner).to receive(:stemcells).and_return({
                  'ubuntu-alias' => Bosh::Director::DeploymentPlan::Stemcell.new('ubuntu-alias', nil, 'ubuntu-jammy', '5.6'),
                  'windows-alias' => Bosh::Director::DeploymentPlan::Stemcell.new('windows-alias', nil, 'windows2019', '7.8'),
                })
              end

              it 'passes stemcell_change: true to the assembler' do
                expect(assembler).to receive(:bind_models).with(hash_including(:stemcell_change => true))

                job.perform
              end
            end

            context 'all stemcell versions have changed and it is overridden with "force_latest_variables"' do
              let(:options) { { 'force_latest_variables' => true } }
              before do
                allow(planner).to receive(:stemcells).and_return({
                  'ubuntu-alias' => Bosh::Director::DeploymentPlan::Stemcell.new('ubuntu-alias', nil, 'ubuntu-jammy', '5.6'),
                  'windows-alias' => Bosh::Director::DeploymentPlan::Stemcell.new('windows-alias', nil, 'windows2019', '7.8'),
                })
              end

              it 'passes stemcell_change: true to the assembler' do
                expect(assembler).to receive(:bind_models).with(hash_including(:stemcell_change => true))

                job.perform
              end
            end

            context 'some stemcell versions have NOT changed and it is not overridden with "force_latest_variables"' do
              before do
                allow(planner).to receive(:stemcells).and_return({
                  'ubuntu-alias' => Bosh::Director::DeploymentPlan::Stemcell.new('ubuntu-alias', nil, 'ubuntu-jammy', '1.2'),
                  'windows-alias' => Bosh::Director::DeploymentPlan::Stemcell.new('windows-alias', nil, 'windows2019', '7.8'),
                })
              end

              it 'passes stemcell_change: false to the assembler' do
                expect(assembler).to receive(:bind_models).with(hash_including(:stemcell_change => false))

                job.perform
              end
            end

            context 'some stemcell versions have NOT changed and it is overridden with "force_latest_variables"' do
              let(:options) { { 'force_latest_variables' => true } }

              before do
                allow(planner).to receive(:stemcells).and_return({
                  'ubuntu-alias' => Bosh::Director::DeploymentPlan::Stemcell.new('ubuntu-alias', nil, 'ubuntu-jammy', '1.2'),
                  'windows-alias' => Bosh::Director::DeploymentPlan::Stemcell.new('windows-alias', nil, 'windows2019', '7.8'),
                })
              end

              it 'passes stemcell_change: true to the assembler' do
                expect(assembler).to receive(:bind_models).with(hash_including(:stemcell_change => true))

                job.perform
              end
            end

            context 'when there is a deleted stemcell and the remaining versions have NOT changed' do
              before do
                allow(planner).to receive(:stemcells).and_return({
                  'windows-alias' => Bosh::Director::DeploymentPlan::Stemcell.new('windows-alias', nil, 'windows2019', '3.4'),
                })
              end

              it 'passes stemcell_change: false to the assembler' do
                expect(assembler).to receive(:bind_models).with(hash_including(:stemcell_change => false))

                job.perform
              end
            end

            context 'when a stemcell alias is renamed and the version has NOT changed' do
              before do
                deployment_model.remove_stemcell(stemcell2)
                allow(planner).to receive(:stemcells).and_return({
                  'ubuntu-alias-renamed' => Bosh::Director::DeploymentPlan::Stemcell.new('ubuntu-alias-renamed', nil, 'ubuntu-jammy', '1.2'),
                })
              end

              it 'passes stemcell_change: false to the assembler' do
                expect(assembler).to receive(:bind_models).with(hash_including(:stemcell_change => false))

                job.perform
              end
            end

            context 'when a stemcell alias is renamed and the version has changed' do
              before do
                deployment_model.remove_stemcell(stemcell2)
                allow(planner).to receive(:stemcells).and_return({
                  'ubuntu-alias-renamed' => Bosh::Director::DeploymentPlan::Stemcell.new('ubuntu-alias-renamed', nil, 'ubuntu-jammy', '3.4'),
                })
              end

              it 'passes stemcell_change: true to the assembler' do
                expect(assembler).to receive(:bind_models).with(hash_including(:stemcell_change => true))

                job.perform
              end
            end
          end

          it 'performs an update' do
            expect(job.perform).to eq('/deployments/simple')
          end

          context 'when the deployment makes changes to existing vms' do
            let(:instance_plan) { instance_double(DeploymentPlan::InstancePlan) }

            it 'will run post-deploy scripts' do
              allow(planner).to receive(:instance_groups).and_return([deployment_instance_group])
              allow(deployment_instance_group).to receive(:did_change).and_return(true)

              expect(PostDeploymentScriptRunner).to receive(:run_post_deploys_after_deployment)

              job.perform
            end
          end

          context 'when manifest_text is specified in options' do
            let(:manifest_text) { '{ name: raw }' }
            let(:options) do
              { 'manifest_text' => manifest_text }
            end

            it 'uses options manifest_text value as manifest_text' do
              expect(Bosh::Director::Manifest).to receive(:load_from_hash).with(Hash, manifest_text, Array, Array)
              job.perform
            end
          end

          context 'when manifest_text is not specified in options' do
            it 'uses manifest value as manifest_text' do
              expect(Bosh::Director::Manifest).to receive(:load_from_hash).with(Hash, manifest_content, Array, Array)
              job.perform
            end
          end

          it 'should store new events' do
            expect {
              job.perform
            }.to change {
              Models::Event.count }.from(0).to(2)

            event_1 = Models::Event.first
            expect(event_1.user).to eq(task.username)
            expect(event_1.object_type).to eq('deployment')
            expect(event_1.deployment).to eq(deployment_name)
            expect(event_1.object_name).to eq(deployment_name)
            expect(event_1.task).to eq("#{task.id}")
            expect(event_1.timestamp).to eq(Time.now)

            event_2 = Models::Event.order(:id).last
            expect(event_2.parent_id).to eq(event_1.id)
            expect(event_2.user).to eq(task.username)
            expect(event_2.object_type).to eq('deployment')
            expect(event_2.deployment).to eq(deployment_name)
            expect(event_2.object_name).to eq(deployment_name)
            expect(event_2.task).to eq("#{task.id}")
            expect(event_2.timestamp).to eq(Time.now)
          end

          context 'when there are releases and stemcells' do
            before do
              deployment_stemcell = FactoryBot.create(:models_stemcell, name: 'stemcell', version: 'version-1')
              deployment_release = FactoryBot.create(:models_release, name: 'release')
              deployment_release_version = FactoryBot.create(:models_release_version, version: 'version-1')
              deployment_release.add_version(deployment_release_version)
              deployment_model.add_stemcell(deployment_stemcell)
              deployment_model.add_release_version(deployment_release_version)
              allow(job).to receive(:current_deployment).and_return(nil, deployment_model)
            end

            it 'should store context of the event' do
              expect {
                job.perform
              }.to change {
                Models::Event.count }.from(0).to(2)
              expect(Models::Event.order(:id).last.context).to eq({'before' => {}, 'after' => {'releases' => ['release/version-1'], 'stemcells' => ['stemcell/version-1']}})
            end
          end

          context 'when `new` option is specified' do
            let(:options) do
              { 'new' => true }
            end

            it 'should store new events with specific action' do
              expect {
                job.perform
              }.to change {
                Models::Event.count }.from(0).to(2)

              expect(Models::Event.first.action).to eq('create')
              expect(Models::Event.order(:id).last.action).to eq('create')
            end
          end

          context 'when `new` option is not specified' do
            it 'should define `update` deployment action' do
              expect {
                job.perform
              }.to change {
                Models::Event.count }.from(0).to(2)
              expect(Models::Event.first.action).to eq('update')
              expect(Models::Event.order(:id).last.action).to eq('update')
            end
          end

          context 'when option deploy is set' do
            let(:options) do
              { 'deploy' => true }
            end
            before do
              allow(Models::Deployment).to receive(:find).with(name: deployment_name).and_return(deployment_model)
              allow(variable_set_1).to receive(:update).with(:deployed_successfully => true)
              allow(links_manager).to receive(:remove_unused_links)
            end
            it 'should mark variable_set.writable to false' do
              expect(variable_set_1).to receive(:update).with({:writable => false})

              job.perform
            end
          end

        end

        context 'when rendering templates fails' do
          let(:expected_result) do
            <<-EXPECTED.strip
Unable to render instance groups for deployment. Errors are:
  - Unable to render jobs for instance group 'my_instance_group_1'. Errors are:
    - Unable to render templates for job 'some_job1'. Errors are:
      - Failed to find variable '/TestDirector/simple/i_am_not_here_1' from config server: HTTP code '404'
      - Failed to find variable '/TestDirector/simple/i_am_not_here_2' from config server: HTTP code '404'
      - Failed to find variable '/TestDirector/simple/i_am_not_here_3' from config server: HTTP code '404'
  - Unable to render jobs for instance group 'my_instance_group_2'. Errors are:
    - Unable to render templates for job 'some_job2'. Errors are:
      - Failed to find variable '/TestDirector/simple/i_am_not_here_1' from config server: HTTP code '404'
      - Failed to find variable '/TestDirector/simple/i_am_not_here_2' from config server: HTTP code '404'
      - Failed to find variable '/TestDirector/simple/i_am_not_here_3' from config server: HTTP code '404'
            EXPECTED
          end
          let(:variable_set_1) { instance_double(Bosh::Director::Models::VariableSet) }

          let(:error_msgs) do
            <<-ERROR_MSGS.strip
- Unable to render jobs for instance group 'my_instance_group_1'. Errors are:
  - Unable to render templates for job 'some_job1'. Errors are:
    - Failed to find variable '/TestDirector/simple/i_am_not_here_1' from config server: HTTP code '404'
    - Failed to find variable '/TestDirector/simple/i_am_not_here_2' from config server: HTTP code '404'
    - Failed to find variable '/TestDirector/simple/i_am_not_here_3' from config server: HTTP code '404'
- Unable to render jobs for instance group 'my_instance_group_2'. Errors are:
  - Unable to render templates for job 'some_job2'. Errors are:
    - Failed to find variable '/TestDirector/simple/i_am_not_here_1' from config server: HTTP code '404'
    - Failed to find variable '/TestDirector/simple/i_am_not_here_2' from config server: HTTP code '404'
    - Failed to find variable '/TestDirector/simple/i_am_not_here_3' from config server: HTTP code '404'
            ERROR_MSGS
          end

          let(:manifest) { instance_double( Bosh::Director::Manifest)}

          before do
            allow(notifier).to receive(:send_start_event)
            allow(JobRenderer).to receive(:render_job_instances_with_cache).and_raise(error_msgs)
            allow(planner).to receive(:instance_models).and_return([])
            allow(Bosh::Director::Manifest).to receive(:load_from_hash).and_return(manifest)
          end

          it 'formats the error messages' do
            expect {
              job.perform
            }.to(raise_error { |error|
              expect(error.message).to eq(expected_result)
            })
          end

          context 'when option deploy is set' do
            let(:options) do
              { 'deploy' => true }
            end
            it 'should mark variable_set.writable to false' do
              allow(Models::Deployment).to receive(:find).with(name: deployment_name).and_return(deployment_model)
              allow(Models::Deployment).to receive(:[]).with(name: deployment_name).and_return(deployment_model)

              allow(deployment_model).to receive(:current_variable_set).and_return(variable_set_1)
              expect(variable_set_1).to receive(:update).with({:writable => false})

              expect {
                job.perform
              }.to raise_error %r{'/TestDirector/simple/i_am_not_here_3' from config server: HTTP code '404'}
            end
          end

          context 'errand variable versioning fails' do
            let(:expected_result) do
              <<-EXPECTED.strip
Unable to render instance groups for deployment. Errors are:
  - Unable to render jobs for instance group 'my_instance_group_1'. Errors are:
    - Unable to render templates for job 'some_job1'. Errors are:
      - Failed to find variable '/TestDirector/simple/i_am_not_here_1' from config server: HTTP code '404'
      - Failed to find variable '/TestDirector/simple/i_am_not_here_2' from config server: HTTP code '404'
      - Failed to find variable '/TestDirector/simple/i_am_not_here_3' from config server: HTTP code '404'
  - Unable to render jobs for instance group 'my_instance_group_2'. Errors are:
    - Unable to render templates for job 'some_job2'. Errors are:
      - Failed to find variable '/TestDirector/simple/i_am_not_here_1' from config server: HTTP code '404'
      - Failed to find variable '/TestDirector/simple/i_am_not_here_2' from config server: HTTP code '404'
      - Failed to find variable '/TestDirector/simple/i_am_not_here_3' from config server: HTTP code '404'
  - Unable to render jobs for instance group 'some-errand-instance-group'. Errors are:
    - Unable to render templates for job 'some_errand_job1'. Errors are:
      - Failed to find variable '/TestDirector/simple/some_property_error' from config server: HTTP code '404'
    - Unable to interpolate link 'some-link-name' properties; provided by 'some_provider_deployment_name' deployment. Errors are:
      - Failed to find variable '/TestDirector/simple/some_link_error' from config server: HTTP code '404'
              EXPECTED
            end

            let(:errand_properties_error) do
              <<-EXPECTED.strip
- Unable to render templates for job 'some_errand_job1'. Errors are:
  - Failed to find variable '/TestDirector/simple/some_property_error' from config server: HTTP code '404'
              EXPECTED
            end

            let(:errand_link_error) do
              <<-EXPECTED.strip
- Unable to interpolate link 'some-link-name' properties; provided by 'some_provider_deployment_name' deployment. Errors are:
  - Failed to find variable '/TestDirector/simple/some_link_error' from config server: HTTP code '404'
              EXPECTED
            end

            before do
              allow(links_manager).to receive(:get_links_for_instance_group).and_return({'job_1' => {'link_1' =>{}}})
              allow(variables_interpolator).to receive(:interpolate_template_spec_properties).and_raise(errand_properties_error)
              allow(variables_interpolator).to receive(:interpolate_link_spec_properties).and_raise(errand_link_error)
            end

            it 'formats the error messages for service & errand instance groups' do
              expect {
                job.perform
              }.to(raise_error { |error|
                expect(error.message).to eq(expected_result)
              })
            end
          end
        end

        context 'when job is being dry-run' do
          let(:manifest) { instance_double( Bosh::Director::Manifest)}
          let(:options) do
            { 'dry_run' => true }
          end

          before do
            allow(JobRenderer).to receive(:render_job_instances_with_cache).with(anything, anything, template_blob_cache, anything, anything)
            allow(planner).to receive(:instance_models).and_return([])
            allow(planner).to receive(:instance_groups).and_return([deployment_instance_group])
            allow(Bosh::Director::Manifest).to receive(:load_from_hash).and_return(manifest)
          end

          it 'should exit before trying to create vms' do
            expect(compile_stage).not_to receive(:perform)
            expect(update_stage).not_to receive(:perform)
            expect(create_network_stage).not_to receive(:perform)
            expect(PostDeploymentScriptRunner).not_to receive(:run_post_deploys_after_deployment)
            expect(notifier).not_to receive(:send_start_event)
            expect(notifier).not_to receive(:send_end_event)

            expect(job.perform).to eq('/deployments/simple')
          end

          context 'when it fails the dry-run' do
            it 'should not send an error event to the health monitor' do
              expect(assembler).to receive(:bind_models).and_raise('error')
              expect(notifier).not_to receive(:send_error_event)

              expect { job.perform }.to raise_error('error')
            end
          end
        end

        describe '#warn_if_recreate_vms_created_before_is_future' do
          let(:manifest) { instance_double(Bosh::Director::Manifest) }

          before do
            allow(Bosh::Director::Manifest).to receive(:load_from_hash).and_return(manifest)
            allow(job).to receive(:with_deployment_lock).and_yield
            job.send(:parse_manifest)
          end

          context 'when timestamp is in the future' do
            let(:future_timestamp) { '2099-01-01T00:00:00Z' }

            it 'emits a warning to the event log' do
              allow(planner).to receive(:recreate_vms_created_before).and_return(future_timestamp)

              expect(Config.event_log).to receive(:warn).with(
                "The recreate_vms_created_before timestamp '#{future_timestamp}' is in the future. " \
                'No VMs will be filtered by age - all VMs marked for recreation will be recreated.',
              )

              job.send(:warn_if_recreate_vms_created_before_is_future)
            end
          end

          context 'when timestamp is in the past' do
            let(:past_timestamp) { '2000-01-01T00:00:00Z' }

            it 'does not emit a warning' do
              allow(planner).to receive(:recreate_vms_created_before).and_return(past_timestamp)

              expect(Config.event_log).not_to receive(:warn)

              job.send(:warn_if_recreate_vms_created_before_is_future)
            end
          end

          context 'when timestamp is not specified' do
            it 'does not emit a warning' do
              allow(planner).to receive(:recreate_vms_created_before).and_return(nil)

              expect(Config.event_log).not_to receive(:warn)

              job.send(:warn_if_recreate_vms_created_before_is_future)
            end
          end
        end

        context 'when the first step fails' do
          let(:manifest) { instance_double( Bosh::Director::Manifest)}

          before do
            expect(notifier).to receive(:send_start_event).ordered
            expect(notifier).to receive(:send_error_event).ordered
            allow(Bosh::Director::Manifest).to receive(:load_from_hash).and_return(manifest)
          end

          it 'does not compile or update' do
            expect {
              job.perform
            }.to raise_error(Exception)
          end
        end
      end

      describe '#dry_run?' do
        context 'when job is being dry run' do
          let(:options) do
            { 'dry_run' => true }
          end

          it 'should return true ' do
            expect(job.dry_run?).to be_truthy
          end
        end

        context 'when job is NOT being dry run' do
          it 'should return false' do
            expect(job.dry_run?).to be_falsey
          end
        end
      end
    end
  end
end
