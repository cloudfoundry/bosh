require 'spec_helper'

module Bosh::Director
  describe InstanceGroupUpdater do
    subject(:instance_group_updater) do
      described_class.new(ip_provider: ip_provider,
                          instance_group: instance_group,
                          disk_manager: disk_manager,
                          template_blob_cache: template_blob_cache,
                          dns_encoder: dns_encoder,
                          link_provider_intents: link_provider_intents)
    end
    let(:link_provider_intents) { [] }
    let(:template_blob_cache) { instance_double(Bosh::Director::Core::Templates::TemplateBlobCache) }
    let(:disk_manager) { DiskManager.new(per_spec_logger) }

    let(:ip_provider) { instance_double('Bosh::Director::DeploymentPlan::IpProvider') }
    let(:dns_encoder) { instance_double(DnsEncoder) }

    let(:canary_updater) { instance_double('Bosh::Director::InstanceUpdater') }
    let(:changed_updater) { instance_double('Bosh::Director::InstanceUpdater') }
    let(:unchanged_updater) { instance_double('Bosh::Director::InstanceUpdater') }

    let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }
    let(:manifest) { 'something' }

    def parsed_event_log_lines_for(task_id)
      yield(
        (Models::Task.first(id: task_id).event_output || '').split("\n").map do |line|
        JSON.parse(line)
        end
      )
    end

    before do
      allow(Bosh::Director::InstanceUpdater).to receive(:new_instance_updater)
        .with(ip_provider, template_blob_cache, dns_encoder,
              link_provider_intents, kind_of(Bosh::Director::EventLog::Task))
        .and_return(canary_updater, changed_updater, unchanged_updater)

      FactoryBot.create(:models_deployment, name: 'test-deployment', manifest: manifest)
    end

    let(:instance_group) do
      instance_double(
        'Bosh::Director::DeploymentPlan::InstanceGroup',
        name: 'instance_group_name',
        update: update_config,
        unneeded_instances: [],
        obsolete_instance_plans: [],
        lifecycle: 'service',
        deployment_name: 'test-deployment',
      )
    end

    let(:update_config) do
      DeploymentPlan::UpdateConfig.new(
        'canaries' => 1,
        'max_in_flight' => 1,
        'canary_watch_time' => '1000-2000',
        'update_watch_time' => '1000-2000',
      )
    end

    describe 'update' do
      let(:needed_instance_plans) { [] }
      let(:update_error) { RuntimeError.new('update failed') }
      let(:instance_deleter) { instance_double('Bosh::Director::InstanceDeleter') }
      let(:task) { FactoryBot.create(:models_task, id: 42, username: 'user') }
      let(:task_writer) { Bosh::Director::TaskDBWriter.new(:event_output, task.id) }
      let(:event_log) { Bosh::Director::EventLog::Log.new(task_writer) }

      before do
        allow(instance_group).to receive(:needed_instance_plans).and_return(needed_instance_plans)
        allow(instance_group).to receive(:did_change=)
        allow(Bosh::Director::InstanceDeleter).to receive(:new).and_return(instance_deleter)
        allow(Bosh::Director::Config).to receive(:event_log).and_return(event_log)
      end

      context 'when instance_group is up to date' do
        let(:serial_id) { 64 }
        let(:deployment_model) { FactoryBot.create(:models_deployment, links_serial_id: serial_id) }
        let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }
        let(:needed_instance) { instance_double(DeploymentPlan::Instance) }
        let(:needed_instance_plans) do
          instance_plan = DeploymentPlan::InstancePlan.new(
            instance: needed_instance,
            desired_instance: DeploymentPlan::DesiredInstance.new,
            existing_instance: nil,
            variables_interpolator: variables_interpolator,
          )
          allow(instance_plan).to receive(:changed?) { false }
          allow(instance_plan).to receive(:should_be_ignored?) { false }
          allow(instance_plan).to receive(:changes) { [] }
          allow(instance_plan).to receive(:persist_current_spec)
          allow(instance_plan).to receive(:instance).and_return(needed_instance)
          [instance_plan]
        end
        let(:links_manager) do
          instance_double(Bosh::Director::Links::LinksManager).tap do |double|
            allow(double).to receive(:resolve_deployment_links)
          end
        end

        let(:instance_model) { FactoryBot.create(:models_instance) }

        before do
          allow(needed_instance).to receive(:instance_group_name).and_return('instance-group-name')
          allow(needed_instance).to receive(:model).and_return(instance_model)
          allow(needed_instance).to receive(:update_variable_set)
          allow(needed_instance).to receive(:deployment_model).and_return(deployment_model)
        end

        it 'should not begin the updating instance_group event stage' do
          instance_group_updater.update

          parsed_event_log_lines_for(task.id) do |events|
            expect(events).to be_empty
          end
        end

        it 'persists the full spec to the database in case something that is not sent to the vm changes' do
          expect(needed_instance_plans.first).to receive(:persist_current_spec)
          instance_group_updater.update
        end
      end

      context 'when instance plans are errands' do
        subject(:instance_group_updater) do
          described_class.new(ip_provider: ip_provider,
                              instance_group: instance_group,
                              disk_manager: disk_manager,
                              template_blob_cache: template_blob_cache,
                              dns_encoder: dns_encoder,
                              link_provider_intents: link_provider_intents)
        end
        let(:instance_group) do
          instance_double(
            'Bosh::Director::DeploymentPlan::InstanceGroup',
            name: 'instance_group_name',
            update: update_config,
            instances: [needed_instance],
            unneeded_instances: [],
            needed_instance_plans: needed_instance_plans,
            obsolete_instance_plans: [],
            lifecycle: 'errand',
            deployment_name: 'test-deployment',
          )
        end

        let(:vm_created) { false }
        let(:needed_instance_model) { nil }
        let(:needed_instance) { instance_double(DeploymentPlan::Instance, vm_created?: vm_created, availability_zone: 'z1', model: needed_instance_model) }
        let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }
        let(:needed_instance_plans) do
          [
            DeploymentPlan::InstancePlan.new(
              instance: needed_instance,
              desired_instance: DeploymentPlan::DesiredInstance.new,
              existing_instance: nil,
              variables_interpolator: variables_interpolator,
            ).tap do |instance_plan|
              allow(instance_plan).to receive(:changed?) { true }
              allow(instance_plan).to receive(:should_be_ignored?) { false }
              allow(instance_plan).to receive(:changes) { [] }
              allow(instance_plan).to receive(:persist_current_spec)
            end,
          ]
        end

        context 'when a vm is already running' do
          let(:vm_created) { true }
          let(:needed_instance_model) do
            instance_double('Bosh::Director::Models::Instance', to_s: 'instance_group_name/fake_uuid (1)')
          end

          it 'applies' do
            expect(canary_updater).to receive(:update)

            instance_group_updater.update

            parsed_event_log_lines_for(task.id) do |events|
              [
                updating_stage_event(index: 1, total: 1, task: 'instance_group_name/fake_uuid (1) (canary)', state: 'started'),
                updating_stage_event(index: 1, total: 1, task: 'instance_group_name/fake_uuid (1) (canary)', state: 'finished'),
              ].each_with_index do |expected_event, index|
                expect(events[index]).to include(expected_event)
              end
            end
          end
        end

        it 'should not apply' do
          instance_group_updater.update

          parsed_event_log_lines_for(task.id) do |events|
            expect(events).to be_empty
          end
        end
      end

      context 'when instance plans should be ignored' do
        let(:needed_instance) { instance_double(DeploymentPlan::Instance) }
        let(:needed_instance_plans) do
          instance_plan = DeploymentPlan::InstancePlan.new(
            instance: needed_instance,
            desired_instance: DeploymentPlan::DesiredInstance.new,
            existing_instance: nil,
            variables_interpolator: variables_interpolator,
          )
          allow(instance_plan).to receive(:changed?) { true }
          allow(instance_plan).to receive(:should_be_ignored?) { true }
          allow(instance_plan).to receive(:changes) { [] }
          allow(instance_plan).to receive(:persist_current_spec)
          [instance_plan]
        end

        it 'should apply the instance plan' do
          instance_group_updater.update

          parsed_event_log_lines_for(task.id) do |events|
            expect(events).to be_empty
          end
        end
      end

      context 'when instance_group needs to be updated' do
        let(:serial_id) { 64 }
        let(:deployment_model) { FactoryBot.create(:models_deployment, links_serial_id: serial_id) }
        let(:canary_model) { instance_double('Bosh::Director::Models::Instance', to_s: 'instance_group_name/fake_uuid (1)') }
        let(:changed_instance_model) do
          instance_double('Bosh::Director::Models::Instance', to_s: 'instance_group_name/fake_uuid (2)')
        end
        let(:canary) { instance_double('Bosh::Director::DeploymentPlan::Instance', availability_zone: nil, index: 1, model: canary_model) }
        let(:links_manager) do
          instance_double(Bosh::Director::Links::LinksManager).tap do |double|
            allow(double).to receive(:bind_links_to_instance)
          end
        end

        let(:changed_instance) { instance_double('Bosh::Director::DeploymentPlan::Instance', availability_zone: nil, index: 2, model: changed_instance_model) }
        let(:unchanged_instance) do
          instance_double('Bosh::Director::DeploymentPlan::Instance', availability_zone: nil, index: 3)
        end
        let(:canary_plan) do
          plan = DeploymentPlan::InstancePlan.new(
            instance: canary,
            desired_instance: DeploymentPlan::DesiredInstance.new,
            existing_instance: nil,
            variables_interpolator: variables_interpolator,
          )
          allow(plan).to receive(:changed?) { true }
          allow(plan).to receive(:should_be_ignored?) { false }
          allow(plan).to receive(:changes) { ['dns'] }
          plan
        end
        let(:changed_instance_plan) do
          plan = DeploymentPlan::InstancePlan.new(
            instance: changed_instance,
            desired_instance: DeploymentPlan::DesiredInstance.new,
            existing_instance: FactoryBot.create(:models_instance),
            variables_interpolator: variables_interpolator,
          )
          allow(plan).to receive(:changed?) { true }
          allow(plan).to receive(:should_be_ignored?) { false }
          allow(plan).to receive(:changes) { ['network'] }
          plan
        end
        let(:unchanged_instance_plan) do
          plan = DeploymentPlan::InstancePlan.new(
            instance: unchanged_instance,
            desired_instance: DeploymentPlan::DesiredInstance.new,
            existing_instance: FactoryBot.create(:models_instance),
            variables_interpolator: variables_interpolator,
          )
          allow(plan).to receive(:changed?) { false }
          allow(plan).to receive(:should_be_ignored?) { false }
          allow(plan).to receive(:changes) { [] }
          allow(plan).to receive(:persist_current_spec)
          allow(plan).to receive(:instance).and_return(unchanged_instance)
          plan
        end

        let(:instance_model) { FactoryBot.create(:models_instance) }

        let(:needed_instance_plans) { [canary_plan, changed_instance_plan, unchanged_instance_plan] }

        before do
          allow(unchanged_instance).to receive(:update_variable_set)
          allow(unchanged_instance).to receive(:instance_group_name).and_return('instance-group-name')
          allow(unchanged_instance).to receive(:model).and_return(instance_model)
          allow(unchanged_instance).to receive(:deployment_model).and_return(deployment_model)
        end

        it 'should update changed instance_group instances with canaries' do
          expect(canary_updater).to receive(:update).with(canary_plan, canary: true)
          expect(changed_updater).to receive(:update).with(changed_instance_plan, canary: false)
          expect(unchanged_updater).to_not receive(:update)

          instance_group_updater.update

          parsed_event_log_lines_for(task.id) do |events|
            [
              updating_stage_event(index: 1, total: 2, task: 'instance_group_name/fake_uuid (1) (canary)', state: 'started'),
              updating_stage_event(index: 1, total: 2, task: 'instance_group_name/fake_uuid (1) (canary)', state: 'finished'),
              updating_stage_event(index: 2, total: 2, task: 'instance_group_name/fake_uuid (2)', state: 'started'),
              updating_stage_event(index: 2, total: 2, task: 'instance_group_name/fake_uuid (2)', state: 'finished'),
            ].each_with_index do |expected_event, index|
              expect(events[index]).to include(expected_event)
            end
          end
        end

        it 'should not continue updating changed instance_group instances if canaries failed' do
          expect(canary_updater).to receive(:update).with(canary_plan, canary: true).and_raise(update_error)
          expect(changed_updater).to_not receive(:update)
          expect(unchanged_updater).to_not receive(:update)

          expect { instance_group_updater.update }.to raise_error(update_error)

          parsed_event_log_lines_for(task.id) do |events|
            [
              updating_stage_event(index: 1, total: 2, task: 'instance_group_name/fake_uuid (1) (canary)', state: 'started'),
              updating_stage_event(index: 1, total: 2, task: 'instance_group_name/fake_uuid (1) (canary)', state: 'failed'),
            ].each_with_index do |expected_event, index|
              expect(events[index]).to include(expected_event)
            end
          end
        end

        it 'should raise an error if updating changed instance_groups instances failed' do
          expect(canary_updater).to receive(:update).with(canary_plan, canary: true)
          expect(changed_updater).to receive(:update).with(changed_instance_plan, canary: false).and_raise(update_error)
          expect(unchanged_updater).to_not receive(:update)

          expect { instance_group_updater.update }.to raise_error(update_error)

          parsed_event_log_lines_for(task.id) do |events|
            [
              updating_stage_event(index: 1, total: 2, task: 'instance_group_name/fake_uuid (1) (canary)', state: 'started'),
              updating_stage_event(index: 1, total: 2, task: 'instance_group_name/fake_uuid (1) (canary)', state: 'finished'),
              updating_stage_event(index: 2, total: 2, task: 'instance_group_name/fake_uuid (2)', state: 'started'),
              updating_stage_event(index: 2, total: 2, task: 'instance_group_name/fake_uuid (2)', state: 'failed'),
            ].each_with_index do |expected_event, index|
              expect(events[index]).to include(expected_event)
            end
          end
        end
      end

      context 'when the instance_group has unneeded instances' do
        let(:instance) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
        let(:instance_plan) { DeploymentPlan::InstancePlan.new(existing_instance: nil, desired_instance: nil, instance: instance, variables_interpolator: variables_interpolator) }
        before { allow(instance_group).to receive(:unneeded_instances).and_return([instance]) }
        before { allow(instance_group).to receive(:obsolete_instance_plans).and_return([instance_plan]) }

        it 'should delete them' do
          allow(Bosh::Director::Config.event_log).to receive(:begin_stage).and_call_original
          expect(Bosh::Director::Config.event_log).to receive(:begin_stage)
            .with('Deleting unneeded instances', 1, ['instance_group_name'])
          expect(instance_deleter).to receive(:delete_instance_plans)
            .with([instance_plan], instance_of(Bosh::Director::EventLog::Stage), max_threads: 1)

          instance_group_updater.update
        end
      end

      context 'when there are multiple AZs' do
        let(:update_config) do
          DeploymentPlan::UpdateConfig.new(
            'canaries' => canaries,
            'max_in_flight' => max_in_flight,
            'canary_watch_time' => '1000-2000',
            'update_watch_time' => '1000-2000',
          )
        end

        let(:canaries) { 1 }
        let(:max_in_flight) { 2 }
        let(:canary_model) { instance_double('Bosh::Director::Models::Instance', to_s: 'instance_group_name/fake_uuid (1)') }

        let(:changed_instance_model_1) do
          instance_double('Bosh::Director::Models::Instance', to_s: 'instance_group_name/fake_uuid (2)')
        end
        let(:changed_instance_model_2) do
          instance_double('Bosh::Director::Models::Instance', to_s: 'instance_group_name/fake_uuid (3)')
        end
        let(:changed_instance_model_3) do
          instance_double('Bosh::Director::Models::Instance', to_s: 'instance_group_name/fake_uuid (4)')
        end

        let(:canary) { instance_double('Bosh::Director::DeploymentPlan::Instance', availability_zone: 'z1', index: 1, model: canary_model) }
        let(:changed_instance_1) { instance_double('Bosh::Director::DeploymentPlan::Instance', availability_zone: 'z1', index: 2, model: changed_instance_model_1) }
        let(:changed_instance_2) { instance_double('Bosh::Director::DeploymentPlan::Instance', availability_zone: 'z2', index: 3, model: changed_instance_model_2) }
        let(:changed_instance_3) { instance_double('Bosh::Director::DeploymentPlan::Instance', availability_zone: 'z2', index: 4, model: changed_instance_model_3) }

        let(:canary_plan) do
          plan = DeploymentPlan::InstancePlan.new(
            instance: canary,
            desired_instance: DeploymentPlan::DesiredInstance.new,
            existing_instance: nil,
            variables_interpolator: variables_interpolator,
          )
          allow(plan).to receive(:changed?) { true }
          allow(plan).to receive(:should_be_ignored?) { false }
          allow(plan).to receive(:changes) { ['dns'] }
          plan
        end
        let(:changed_instance_plan_1) do
          plan = DeploymentPlan::InstancePlan.new(
            instance: changed_instance_1,
            desired_instance: DeploymentPlan::DesiredInstance.new,
            existing_instance: FactoryBot.create(:models_instance),
            variables_interpolator: variables_interpolator,
          )
          allow(plan).to receive(:changed?) { true }
          allow(plan).to receive(:should_be_ignored?) { false }
          allow(plan).to receive(:changes) { ['network'] }
          plan
        end
        let(:changed_instance_plan_2) do
          plan = DeploymentPlan::InstancePlan.new(
            instance: changed_instance_2,
            desired_instance: DeploymentPlan::DesiredInstance.new,
            existing_instance: FactoryBot.create(:models_instance),
            variables_interpolator: variables_interpolator,
          )
          allow(plan).to receive(:changed?) { true }
          allow(plan).to receive(:should_be_ignored?) { false }
          allow(plan).to receive(:changes) { ['network'] }
          plan
        end
        let(:changed_instance_plan_3) do
          plan = DeploymentPlan::InstancePlan.new(
            instance: changed_instance_3,
            desired_instance: DeploymentPlan::DesiredInstance.new,
            existing_instance: FactoryBot.create(:models_instance),
            variables_interpolator: variables_interpolator,
          )
          allow(plan).to receive(:changed?) { true }
          allow(plan).to receive(:should_be_ignored?) { false }
          allow(plan).to receive(:changes) { ['network'] }
          plan
        end

        let(:needed_instance_plans) { [canary_plan, changed_instance_plan_1, changed_instance_plan_2, changed_instance_plan_3] }

        let(:canary_updater) { instance_double('Bosh::Director::InstanceUpdater') }
        let(:changed_updater) { instance_double('Bosh::Director::InstanceUpdater') }

        before do
          allow(Bosh::Director::InstanceUpdater).to receive(:new_instance_updater)
            .with(ip_provider, template_blob_cache, dns_encoder,
                  link_provider_intents,
                  kind_of(Bosh::Director::EventLog::Task))
            .and_return(canary_updater, changed_updater)
        end

        it 'should finish the max_in_flight for an AZ before beginning the next AZ' do
          expect(canary_updater).to receive(:update).with(canary_plan, canary: true)
          expect(changed_updater).to receive(:update).with(changed_instance_plan_1, canary: false)
          expect(changed_updater).to receive(:update).with(changed_instance_plan_2, canary: false)
          expect(changed_updater).to receive(:update).with(changed_instance_plan_3, canary: false)

          instance_group_updater.update

          parsed_event_log_lines_for(task.id) do |events|
            [
              updating_stage_event(index: 1, total: 4, task: 'instance_group_name/fake_uuid (1) (canary)', state: 'started'),
              updating_stage_event(index: 1, total: 4, task: 'instance_group_name/fake_uuid (1) (canary)', state: 'finished'),
              updating_stage_event(index: 2, total: 4, task: 'instance_group_name/fake_uuid (2)', state: 'started'),
              updating_stage_event(index: 2, total: 4, task: 'instance_group_name/fake_uuid (2)', state: 'finished'),
            ].each_with_index do |expected_event, index|
              expect(events[index]).to include(expected_event)
            end

            # blocked until next az...
            last_events = events[3..-1]
            expected_events = [
              updating_stage_event(total: 4, task: 'instance_group_name/fake_uuid (3)', state: 'started'),
              updating_stage_event(total: 4, task: 'instance_group_name/fake_uuid (4)', state: 'started'),
              updating_stage_event(total: 4, task: 'instance_group_name/fake_uuid (3)', state: 'finished'),
              updating_stage_event(total: 4, task: 'instance_group_name/fake_uuid (4)', state: 'finished'),
            ]
            expected_events.map do |expected_event|
              expect(last_events.select { |event| same_event?(event, expected_event) }).not_to be_empty
            end
          end
        end

        context 'when max_in_flight and canaries are specified as percents' do
          let(:canaries) { '50%' }
          let(:max_in_flight) { '100%' }

          it 'should understand it' do
            expect(canary_updater).to receive(:update).with(canary_plan, canary: true)
            expect(changed_updater).to receive(:update).with(changed_instance_plan_1, canary: false)
            expect(changed_updater).to receive(:update).with(changed_instance_plan_2, canary: false)
            expect(changed_updater).to receive(:update).with(changed_instance_plan_3, canary: false)

            instance_group_updater.update

            parsed_event_log_lines_for(task.id) do |events|
              [
                updating_stage_event(index: 1, total: 4, task: 'instance_group_name/fake_uuid (1) (canary)', state: 'started'),
                updating_stage_event(index: 1, total: 4, task: 'instance_group_name/fake_uuid (1) (canary)', state: 'finished'),
                updating_stage_event(index: 2, total: 4, task: 'instance_group_name/fake_uuid (2)', state: 'started'),
                updating_stage_event(index: 2, total: 4, task: 'instance_group_name/fake_uuid (2)', state: 'finished'),
              ].each_with_index do |expected_event, index|
                expect(events[index]).to include(expected_event)
              end

              # blocked until next az...
              last_events = events[3..-1]
              expected_events = [
                updating_stage_event(total: 4, task: 'instance_group_name/fake_uuid (3)', state: 'started'),
                updating_stage_event(total: 4, task: 'instance_group_name/fake_uuid (4)', state: 'started'),
                updating_stage_event(total: 4, task: 'instance_group_name/fake_uuid (3)', state: 'finished'),
                updating_stage_event(total: 4, task: 'instance_group_name/fake_uuid (4)', state: 'finished'),
              ]
              expected_events.map do |expected_event|
                expect(last_events.select { |event| same_event?(event, expected_event) }).not_to be_empty
              end
            end
          end
        end

        context 'and initial_deploy_az_update_strategy is set to parallel' do
          # change order of instance plans to ensure that azs are being grouped correctly
          let(:needed_instance_plans) { [canary_plan, changed_instance_plan_2, changed_instance_plan_1, changed_instance_plan_3] }
          let(:canaries) { 1 }
          let(:max_in_flight) { 1 }

          let(:update_config) do
            DeploymentPlan::UpdateConfig.new(
              'canaries' => canaries,
              'max_in_flight' => max_in_flight,
              'canary_watch_time' => '1000-2000',
              'update_watch_time' => '1000-2000',
              'initial_deploy_az_update_strategy' => 'parallel',
            )
          end

          context 'and its the initial deploy' do
            let(:manifest) { nil }

            it 'should update all instances in parallel across all azs' do
              expect(canary_updater).to receive(:update).with(canary_plan, canary: true)
              expect(changed_updater).to receive(:update).with(changed_instance_plan_1, canary: false)
              expect(changed_updater).to receive(:update).with(changed_instance_plan_2, canary: false)
              expect(changed_updater).to receive(:update).with(changed_instance_plan_3, canary: false)

              instance_group_updater.update

              parsed_event_log_lines_for(task.id) do |events|
                [
                  updating_stage_event(index: 1, total: 4, task: 'instance_group_name/fake_uuid (1) (canary)', state: 'started'),
                  updating_stage_event(index: 1, total: 4, task: 'instance_group_name/fake_uuid (1) (canary)', state: 'finished'),
                  updating_stage_event(total: 4, task: 'instance_group_name/fake_uuid (3)', state: 'started'),
                  updating_stage_event(total: 4, task: 'instance_group_name/fake_uuid (3)', state: 'finished'),
                  updating_stage_event(total: 4, task: 'instance_group_name/fake_uuid (2)', state: 'started'),
                  updating_stage_event(total: 4, task: 'instance_group_name/fake_uuid (2)', state: 'finished'),
                  updating_stage_event(total: 4, task: 'instance_group_name/fake_uuid (4)', state: 'started'),
                  updating_stage_event(total: 4, task: 'instance_group_name/fake_uuid (4)', state: 'finished'),
                ].each_with_index do |expected_event, index|
                  expect(events[index]).to include(expected_event)
                end
              end
            end
          end

          context 'and its a subsequent deploy' do
            let(:manifest) { 'this is a manifest' }

            it 'should update all instances in parallel across all azs' do
              expect(canary_updater).to receive(:update).with(canary_plan, canary: true)
              expect(changed_updater).to receive(:update).with(changed_instance_plan_1, canary: false)
              expect(changed_updater).to receive(:update).with(changed_instance_plan_2, canary: false)
              expect(changed_updater).to receive(:update).with(changed_instance_plan_3, canary: false)

              instance_group_updater.update

              parsed_event_log_lines_for(task.id) do |events|
                [
                  updating_stage_event(index: 1, total: 4, task: 'instance_group_name/fake_uuid (1) (canary)', state: 'started'),
                  updating_stage_event(index: 1, total: 4, task: 'instance_group_name/fake_uuid (1) (canary)', state: 'finished'),
                  updating_stage_event(index: 2, total: 4, task: 'instance_group_name/fake_uuid (2)', state: 'started'),
                  updating_stage_event(index: 2, total: 4, task: 'instance_group_name/fake_uuid (2)', state: 'finished'),
                  updating_stage_event(total: 4, task: 'instance_group_name/fake_uuid (3)', state: 'started'),
                  updating_stage_event(total: 4, task: 'instance_group_name/fake_uuid (3)', state: 'finished'),
                  updating_stage_event(total: 4, task: 'instance_group_name/fake_uuid (4)', state: 'started'),
                  updating_stage_event(total: 4, task: 'instance_group_name/fake_uuid (4)', state: 'finished'),
                ].each_with_index do |expected_event, index|
                  expect(events[index]).to include(expected_event)
                end
              end
            end
          end
        end
      end
    end

    def updating_stage_event(options)
      events = {
        'stage' => 'Updating instance',
        'tags' => ['instance_group_name'],
        'total' => options[:total],
        'task' => options[:task],
        'state' => options[:state],
      }
      events['index'] = options[:index] if options.key?(:index)
      events
    end

    def same_event?(event, expected_event)
      expected_event.each do |k, v|
        return false if event[k] != v
      end
      true
    end
  end
end
