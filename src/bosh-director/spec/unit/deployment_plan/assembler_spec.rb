require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::Assembler do
    subject(:assembler) { DeploymentPlan::Assembler.new(deployment_plan, stemcell_manager, powerdns_manager) }
    let(:deployment_plan) { instance_double('Bosh::Director::DeploymentPlan::Planner',
      name: 'simple',
      using_global_networking?: false,
      skip_drain: BD::DeploymentPlan::AlwaysSkipDrain.new,
      recreate: false,
      model: BD::Models::Deployment.make,

    ) }
    let(:stemcell_manager) { nil }
    let(:powerdns_manager) { PowerDnsManagerProvider.create }
    let(:event_log) { Config.event_log }

    describe '#bind_models' do
      let(:instance_model) { Models::Instance.make(job: 'old-name') }
      let(:instance_group) { instance_double(DeploymentPlan::InstanceGroup) }

      before do
        allow(deployment_plan).to receive(:instance_models).and_return([instance_model])
        allow(deployment_plan).to receive(:instance_groups).and_return([])
        allow(deployment_plan).to receive(:existing_instances).and_return([])
        allow(deployment_plan).to receive(:candidate_existing_instances).and_return([])
        allow(deployment_plan).to receive(:resource_pools).and_return(nil)
        allow(deployment_plan).to receive(:stemcells).and_return({})
        allow(deployment_plan).to receive(:instance_groups_starting_on_deploy).and_return([])
        allow(deployment_plan).to receive(:releases).and_return([])
        allow(deployment_plan).to receive(:uninterpolated_manifest_hash).and_return({})
        allow(deployment_plan).to receive(:mark_instance_plans_for_deletion)
        allow(deployment_plan).to receive(:deployment_wide_options).and_return({})
        allow(deployment_plan).to receive(:use_dns_addresses?).and_return(false)
        allow(deployment_plan).to receive(:use_short_dns_addresses?).and_return(false)
        allow(deployment_plan).to receive(:randomize_az_placement?).and_return(false)
      end

      it 'should bind releases and their templates' do
        r1 = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'r1')
        r2 = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'r2')

        allow(deployment_plan).to receive(:releases).and_return([r1, r2])

        expect(r1).to receive(:bind_model)
        expect(r2).to receive(:bind_model)

        expect(r1).to receive(:bind_templates)
        expect(r2).to receive(:bind_templates)

        expect(assembler).to receive(:with_release_locks).with(['r1', 'r2']).and_yield
        assembler.bind_models
      end

      context 'overriding instances to bind' do
        let(:instance_model_to_override) { instance_double(Models::Instance, job: 'override', vm_cid: 'cid', ignore: false) }

        it 'only binds the provided instances' do
          agent_state_migrator = instance_double(DeploymentPlan::AgentStateMigrator)
          allow(DeploymentPlan::AgentStateMigrator).to receive(:new).and_return(agent_state_migrator)
          expect(agent_state_migrator).to receive(:get_state).with(instance_model_to_override)

          assembler.bind_models(instances: [instance_model_to_override])
        end
      end

      describe 'migrate_legacy_dns_records' do
        it 'migrates legacy dns records' do
          expect(powerdns_manager).to receive(:migrate_legacy_records).with(instance_model)
          assembler.bind_models
        end
      end

      it 'should bind stemcells' do
        sc1 = instance_double('Bosh::Director::DeploymentPlan::Stemcell')
        sc2 = instance_double('Bosh::Director::DeploymentPlan::Stemcell')

        expect(deployment_plan).to receive(:stemcells).and_return({'sc1' => sc1, 'sc2' => sc2})

        expect(sc1).to receive(:bind_model)
        expect(sc2).to receive(:bind_model)

        assembler.bind_models
      end

      context 'contains deployment plan tags' do
        before do
          allow(deployment_plan).to receive(:deployment_wide_options).and_return({
            tags: {'key1' => 'value1'}
          })
        end

        it 'passes tags to instance plan factory' do
          expected_options = {'recreate' => false, 'tags' => {'key1' => 'value1'}, 'use_dns_addresses' => false, 'use_short_dns_addresses' => false,'randomize_az_placement' => false}
          expect(DeploymentPlan::InstancePlanFactory).to receive(:new).with(anything, anything, anything, anything, anything, expected_options).and_call_original
          assembler.bind_models({tags: {'key1' => 'value1'}})
        end
      end

      context 'contains deployment use_dns_addresses and randomize_az_placement features' do
        context 'when TRUE' do
          before do
            allow(deployment_plan).to receive(:use_dns_addresses?).and_return(true)
            allow(deployment_plan).to receive(:randomize_az_placement?).and_return(true)
          end

          it 'passes use_dns_addresses, use_short_dns_addresses and randomize_az_placement feature flags to instance plan factory' do
            expected_options = {'recreate' => false, 'tags' => {}, 'use_dns_addresses' => true, 'randomize_az_placement' => true, 'use_short_dns_addresses' => false}
            expect(DeploymentPlan::InstancePlanFactory).to receive(:new).with(anything, anything, anything, anything, anything, expected_options).and_call_original
            assembler.bind_models
          end

          context 'contains deployment use_short_dns_addresses feature as TRUE' do
            before do
              allow(deployment_plan).to receive(:use_short_dns_addresses?).and_return(true)
            end

            it 'passes use_short_dns_addresses to instance plan factory' do
              expected_options = {'recreate' => false, 'tags' => {}, 'use_dns_addresses' => true, 'randomize_az_placement' => true, 'use_short_dns_addresses' => true}
              expect(DeploymentPlan::InstancePlanFactory).to receive(:new).with(anything, anything, anything, anything, anything, expected_options).and_call_original
              assembler.bind_models
            end
          end
        end

        context 'when FALSE' do
          before do
            allow(deployment_plan).to receive(:use_dns_addresses?).and_return(false)
            allow(deployment_plan).to receive(:randomize_az_placement?).and_return(false)
          end

          it 'passes use_dns_addresses, use_short_dns_addresses and randomize_az_placement to instance plan factory' do
            expected_options = {'recreate' => false, 'tags' => {}, 'use_dns_addresses' => false, 'randomize_az_placement' => false, 'use_short_dns_addresses' => false}
            expect(DeploymentPlan::InstancePlanFactory).to receive(:new).with(anything, anything, anything, anything, anything, expected_options).and_call_original
            assembler.bind_models
          end
        end
      end

      context 'when there are desired instance_groups' do
        def make_instance_group(name, template_name)
          instance_group = DeploymentPlan::InstanceGroup.new(logger)
          instance_group.name = name
          instance_group.deployment_name = 'simple'
          template_model = Models::Template.make(name: template_name)
          release_version = instance_double(DeploymentPlan::ReleaseVersion)
          allow(release_version).to receive(:get_template_model_by_name).and_return(template_model)
          job = DeploymentPlan::Job.new(release_version, template_name, deployment_plan.name)
          job.bind_models
          instance_group.jobs = [job]
          allow(instance_group).to receive(:validate_package_names_do_not_collide!)
          instance_group
        end

        let(:instance_group_1) { make_instance_group('ig-1', 'fake-instance-group-1') }
        let(:instance_group_2) { make_instance_group('ig-2', 'fake-instance-group-2') }

        let(:instance_group_network) { double(DeploymentPlan::JobNetwork) }

        before do
          allow(instance_group_network).to receive(:name).and_return('my-network-name')
          allow(instance_group_network).to receive(:vip?).and_return(false)
          allow(instance_group_network).to receive(:static_ips)
          allow(instance_group_1).to receive(:networks).and_return([instance_group_network])
          allow(instance_group_2).to receive(:networks).and_return([instance_group_network])

          allow(deployment_plan).to receive(:instance_groups).and_return([instance_group_1, instance_group_2])
          allow(deployment_plan).to receive(:vm_resources_cache)

          allow(deployment_plan).to receive(:name).and_return([instance_group_1, instance_group_2])
        end

        it 'validates the instance_groups' do
          expect(instance_group_1).to receive(:validate_package_names_do_not_collide!).once
          expect(instance_group_2).to receive(:validate_package_names_do_not_collide!).once

          assembler.bind_models
        end

        context 'links binding' do
          let(:links_resolver) { double(DeploymentPlan::LinksResolver) }

          before do
            allow(DeploymentPlan::LinksResolver).to receive(:new).with(deployment_plan, logger).and_return(links_resolver)
            allow(links_resolver).to receive(:add_providers)
          end

          it 'should bind links by default' do
            expect(links_resolver).to receive(:resolve).with(instance_group_1)
            expect(links_resolver).to receive(:resolve).with(instance_group_2)

            assembler.bind_models
          end

          it 'should skip links binding when should_bind_links flag is passed as false' do
            expect(links_resolver).to_not receive(:resolve)

            assembler.bind_models({:should_bind_links => false})
          end

          it 'should clean up unreferenced link_providers after binding' do
            Models::LinkProvider.create(
              name: 'old',
              deployment: deployment_plan.model,
              instance_group: 'ig-1',
              link_provider_definition_type: 'creds',
              link_provider_definition_name: 'login',
              consumable: true,
              shared: false,
              content: '{"user":"bob","password":"jim"}',
              owner_object_type: 'Job',
              owner_object_name: 'oldjob'
            )

            expect(links_resolver).to receive(:resolve).with(instance_group_1)
            expect(links_resolver).to receive(:resolve).with(instance_group_2)
            allow(deployment_plan).to receive(:link_providers).and_return([])

            expect(Models::LinkProvider.count).to eq(1)
            assembler.bind_models
            expect(Models::LinkProvider.all).to be_empty
          end

          it 'should clean up unreferenced link_consumers after binding' do
            Models::LinkConsumer.create(
              deployment: deployment_plan.model,
              instance_group: 'ig-1',
              owner_object_type: 'Job',
              owner_object_name: 'oldjob'
            )

            new_consumer = Models::LinkConsumer.create(
              deployment: deployment_plan.model,
              instance_group: 'ig-1',
              owner_object_type: 'Job',
              owner_object_name: 'newjob'
            )

            expect(links_resolver).to receive(:resolve).with(instance_group_1)
            expect(links_resolver).to receive(:resolve).with(instance_group_2)
            allow(deployment_plan).to receive(:link_consumers).and_return([new_consumer])

            expect(Models::LinkConsumer.count).to eq(2)
            assembler.bind_models
            expect(Models::LinkConsumer.count).to eq(1)
            expect(Models::LinkConsumer.first[:id]).to eq(new_consumer[:id])
          end

          it 'should only preserve link_providers referenced after binding' do
            Models::LinkProvider.create(
              name: 'old',
              deployment: deployment_plan.model,
              instance_group: 'ig-1',
              link_provider_definition_type: 'creds',
              link_provider_definition_name: 'login',
              consumable: true,
              shared: false,
              content: '{"user":"bob","password":"jim"}',
              owner_object_type: 'Job',
              owner_object_name: 'oldjob'
            )

            new_provider = Models::LinkProvider.create(
              name: 'new',
              deployment: deployment_plan.model,
              instance_group: 'ig-1',
              link_provider_definition_type: 'creds',
              link_provider_definition_name: 'login',
              consumable: true,
              shared: false,
              content: '{"user":"jim","password":"bob"}',
              owner_object_type: 'Job',
              owner_object_name: 'newjob'
            )

            expect(links_resolver).to receive(:resolve).with(instance_group_1)
            expect(links_resolver).to receive(:resolve).with(instance_group_2)
            allow(deployment_plan).to receive(:link_providers).and_return([new_provider])

            expect(Models::LinkProvider.count).to eq(2)
            assembler.bind_models
            expect(Models::LinkProvider.count).to eq(1)
            expect(Models::LinkProvider.first[:id]).to eq(new_provider[:id])
          end
        end

        context 'properties binding' do
          it 'should bind properties by default' do
            expect(instance_group_1).to receive(:bind_properties)
            expect(instance_group_2).to receive(:bind_properties)

            assembler.bind_models
          end

          it 'should skip links binding when should_bind_properties flag is passed as false' do
            expect(instance_group_1).to_not receive(:bind_properties)
            expect(instance_group_2).to_not receive(:bind_properties)

            assembler.bind_models({:should_bind_properties => false})
          end
        end

        context 'variable sets binding' do
          before do
            deployment_plan.model.add_variable_set(:created_at => Time.now, :writable => true)
          end

          context 'when should_bind_new_variable_set flag is false' do
            let(:should_bind_new_variable_set) { false }

            it 'should not bind the instance plans variable sets' do
              current_deployment_variable_set = deployment_plan.model.current_variable_set

              expect(instance_group_1).to_not receive(:bind_new_variable_set).with(current_deployment_variable_set)
              expect(instance_group_2).to_not receive(:bind_new_variable_set).with(current_deployment_variable_set)

              assembler.bind_models({:should_bind_new_variable_set => should_bind_new_variable_set})
            end
          end

          context 'when bind_new_variable_set flag is true' do
            let(:should_bind_new_variable_set) { true }

            it 'binds the instance plans variable sets correctly' do
              current_deployment_variable_set = deployment_plan.model.current_variable_set

              expect(instance_group_1).to receive(:bind_new_variable_set).with(current_deployment_variable_set)
              expect(instance_group_2).to receive(:bind_new_variable_set).with(current_deployment_variable_set)

              assembler.bind_models({:should_bind_new_variable_set => should_bind_new_variable_set})
            end
          end

          context 'when bind_new_variable_set flag is not passed' do
            it 'defaults value to false' do
              current_deployment_variable_set = deployment_plan.model.current_variable_set

              expect(instance_group_1).to_not receive(:bind_new_variable_set).with(current_deployment_variable_set)
              expect(instance_group_2).to_not receive(:bind_new_variable_set).with(current_deployment_variable_set)

              assembler.bind_models
            end
          end
        end

        context 'when the instance_group validation fails' do
          it 'propagates the exception' do
            expect(instance_group_1).to receive(:validate_package_names_do_not_collide!).once
            expect(instance_group_2).to receive(:validate_package_names_do_not_collide!).once.and_raise('Unable to deploy manifest')

            expect { assembler.bind_models }.to raise_error('Unable to deploy manifest')
          end
        end
      end

      it 'configures dns' do
        expect(powerdns_manager).to receive(:configure_nameserver)
        assembler.bind_models
      end

      context 'when agent get_state raises an error' do
        [RpcTimeout, RpcRemoteException].each do |error|
          context "and the error is an #{error}" do
            let(:instance_model_to_override) { instance_double(Models::Instance, name: 'TestInstance/TestUUID', uuid: 'TestUUID', job: 'override', vm_cid: 'cid', ignore: false) }

            context 'when fix is specified' do

              before do
                allow(deployment_plan).to receive(:deployment_wide_options).and_return(fix: true)
              end

              it 'handles it' do
                agent_state_migrator = instance_double(DeploymentPlan::AgentStateMigrator)
                allow(DeploymentPlan::AgentStateMigrator).to receive(:new).and_return(agent_state_migrator)
                expect(agent_state_migrator).to receive(:get_state).and_raise(error)

                expect {
                  assembler.bind_models(instances: [instance_model_to_override])
                }.not_to raise_error

              end
            end

            context 'when fix is not specified' do
              it 'enhances error message' do
                agent_state_migrator = instance_double(DeploymentPlan::AgentStateMigrator)
                allow(DeploymentPlan::AgentStateMigrator).to receive(:new).and_return(agent_state_migrator)
                expect(agent_state_migrator).to receive(:get_state).and_raise(error, 'initial error')


                expect {
                  assembler.bind_models(instances: [instance_model_to_override])
                }.to raise_error error, "#{instance_model_to_override.name}: initial error"
              end
            end
          end
        end
      end
    end

    describe '.create' do
      it 'initializes a DeploymentPlan::Assembler with the correct deployment_plan and makes stemcell and dns managers' do
        expect(DeploymentPlan::Assembler).to receive(:new).with(
          deployment_plan,
          an_instance_of(Api::StemcellManager),
          an_instance_of(PowerDnsManager),
        ).and_call_original

        DeploymentPlan::Assembler.create(deployment_plan)
      end
    end
  end
end
