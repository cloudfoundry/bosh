require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::Assembler do
    subject(:assembler) { DeploymentPlan::Assembler.new(deployment_plan, stemcell_manager, powerdns_manager) }
    let(:deployment_plan) { instance_double('Bosh::Director::DeploymentPlan::Planner',
      name: 'simple',
      using_global_networking?: false,
      skip_drain: BD::DeploymentPlan::AlwaysSkipDrain.new,
      recreate: false,
      model: deployment_model,

    ) }

    let(:deployment_model) {BD::Models::Deployment.make}
    let(:stemcell_manager) {nil}
    let(:powerdns_manager) {PowerDnsManagerProvider.create}
    let(:event_log) {Config.event_log}
    let(:links_manager_factory) do
      instance_double(Bosh::Director::Links::LinksManagerFactory).tap do |double|
        expect(double).to receive(:create_manager).and_return(links_manager)
      end
    end

    let(:links_manager) do
      instance_double(Bosh::Director::Links::LinksManager).tap do |double|
        allow(double).to receive(:resolve_deployment_links)
      end
    end

    before do
      allow(Bosh::Director::Links::LinksManagerFactory).to receive(:create).and_return(links_manager_factory)
      allow(links_manager).to receive(:update_provider_intents_contents)
    end

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

        expect(assembler).to receive(:with_release_lock).with('r1').and_yield
        expect(assembler).to receive(:with_release_lock).with('r2').and_yield
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
          let(:resolver_options) {{dry_run: false, global_use_dns_entry: boolean}}

          let(:provider) do
            Models::Links::LinkProvider.make(
              deployment: deployment_model,
              instance_group: 'foo-ig',
              name: 'foo-provider',
              type: 'job'
            )
          end

          let(:provider_intent) do
            Models::Links::LinkProviderIntent.make(
              :link_provider => provider,
              :original_name => 'link_original_name_1',
              :name => 'link_name_1',
              :type => 'link_type_1',
              :shared => true,
              :consumable => true,
              :content => '{}',
              :metadata => {'mapped_properties' => {'a' => 'foo'}}.to_json
            )
          end

          let(:link_providers) do
            [provider]
          end

          before do
            allow(deployment_model).to receive(:link_providers).and_return(link_providers)
          end

          it 'should bind links by default' do
            expect(links_manager).to receive(:update_provider_intents_contents).with(link_providers, deployment_plan).ordered
            expect(links_manager).to receive(:resolve_deployment_links).with(deployment_plan.model, resolver_options).ordered

            assembler.bind_models(is_deploy_action: true)
          end

          it 'should skip links binding when should_bind_links flag is passed as false' do
            expect(links_manager).to_not receive(:update_provider_intents_contents)
            expect(links_manager).to_not receive(:resolve_deployment_links)

            assembler.bind_models({:should_bind_links => false})
          end

          context 'when the links are stale' do
            before do
              deployment_model.has_stale_errand_links = true
            end

            it 'should clear the errand links stale flag in the end' do
              assembler.bind_models(is_deploy_action: true)

              expect(deployment_model.has_stale_errand_links).to be_falsey
            end
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

        context 'when there is an instance to create-swap-delete' do
          let(:instance_planner) { double(DeploymentPlan::InstancePlanner) }
          let(:existing_network_plan1) { DeploymentPlan::NetworkPlanner::Plan.new(reservation: anything, existing: true) }
          let(:existing_network_plan2) { DeploymentPlan::NetworkPlanner::Plan.new(reservation: anything, existing: true) }
          let(:instance) { instance_double(DeploymentPlan::Instance, model: anything) }
          let(:network) { instance_double(DeploymentPlan::Network, name: 'network') }
          let(:create_swap_delete_instance_plan) do
            DeploymentPlan::InstancePlan.new(existing_instance: anything, desired_instance: anything, instance: instance)
          end
          let(:not_create_swap_delete_instance_plan) do
            DeploymentPlan::InstancePlan.new(existing_instance: anything, desired_instance: anything, instance: instance)
          end

          before do
            create_swap_delete_instance_plan.network_plans << existing_network_plan1
            not_create_swap_delete_instance_plan.network_plans << existing_network_plan2

            allow(DeploymentPlan::InstancePlanner).to receive(:new).and_return(instance_planner)
            allow(instance_planner).to receive(:plan_instance_group_instances).and_return(create_swap_delete_instance_plan)
            allow(instance_planner).to receive(:plan_obsolete_instance_groups)
            allow(create_swap_delete_instance_plan).to receive(:should_create_swap_delete?).and_return(true)
            allow(not_create_swap_delete_instance_plan).to receive(:should_create_swap_delete?).and_return(false)
            allow(instance_group_network).to receive(:deployment_network).and_return(network)
            allow(instance_group_1).to receive(:sorted_instance_plans).and_return([create_swap_delete_instance_plan])
            allow(instance_group_2).to receive(:sorted_instance_plans).and_return([not_create_swap_delete_instance_plan])
          end

          context 'and it should be recreated for a non network reason' do
            before do
              allow(create_swap_delete_instance_plan).to receive(:recreate_for_non_network_reasons?).and_return(true)
            end

            it 'creates a desired network reservation for each existing reservation' do
              assembler.bind_models

              expect(create_swap_delete_instance_plan.network_plans.size).to eq(2)
              expect(existing_network_plan1.obsolete?).to eq(true)
              expect(existing_network_plan1.existing?).to eq(false)
              expect(
                create_swap_delete_instance_plan.network_plans.map(&:reservation),
              ).to include(a_kind_of(DesiredNetworkReservation))

              expect(not_create_swap_delete_instance_plan.network_plans.size).to eq(1)
              expect(existing_network_plan2.obsolete?).to eq(false)
              expect(existing_network_plan2.existing?).to eq(true)
              expect(
                not_create_swap_delete_instance_plan.network_plans.map(&:reservation),
              ).to_not include(a_kind_of(DesiredNetworkReservation))
            end
          end

          context 'and it should not be recreated' do
            before do
              allow(create_swap_delete_instance_plan).to receive(:recreate_for_non_network_reasons?).and_return(false)
            end

            it 'it does not change the network plan' do
              assembler.bind_models

              expect(create_swap_delete_instance_plan.network_plans.size).to eq(1)
              expect(existing_network_plan1.obsolete?).to eq(false)
              expect(existing_network_plan1.existing?).to eq(true)
              expect(
                create_swap_delete_instance_plan.network_plans.map(&:reservation),
              ).to_not include(a_kind_of(DesiredNetworkReservation))

              expect(not_create_swap_delete_instance_plan.network_plans.size).to eq(1)
              expect(existing_network_plan2.obsolete?).to eq(false)
              expect(existing_network_plan2.existing?).to eq(true)
              expect(
                not_create_swap_delete_instance_plan.network_plans.map(&:reservation),
              ).to_not include(a_kind_of(DesiredNetworkReservation))
            end
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
