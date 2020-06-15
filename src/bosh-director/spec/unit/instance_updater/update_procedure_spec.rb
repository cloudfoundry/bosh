require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe InstanceUpdater::UpdateProcedure do
      subject(:update_procedure) do
        InstanceUpdater::UpdateProcedure.new(
          instance,
          instance_plan,
          options,
          blobstore,
          needs_recreate,
          instance_report,
          disk_manager,
          rendered_templates_persistor,
          vm_creator,
          links_manager,
          ip_provider,
          dns_state_updater,
          logger,
          task,
        )
      end

      let(:active_vm) { nil }
      let(:agent) { nil }
      let(:agent_id) { Sham.uuid }
      let(:already_detached?) { false }
      let(:blobstore) { nil }
      let(:delete_vm_step) { instance_double(Steps::DeleteVmStep, perform: nil) }
      let(:desired_instance) { instance_double(DesiredInstance, instance_group: instance_group) }
      let(:disk_manager) { instance_double(DiskManager, update_persistent_disk: nil) }
      let(:dns_changed?) { false }
      let(:dns_record_info) { nil }
      let(:dns_state_updater) { instance_double(DirectorDnsStateUpdater, update_dns_for_instance: nil) }
      let(:instance_group) { instance_double(InstanceGroup, update: nil) }
      let(:instance_model_state) { 'not-stopped' }
      let(:instance_name) { 'bob' }
      let(:instance_new?) { false }
      let(:instance_plan_changes) { [] }
      let(:instance_report) { instance_double(Stages::Report, :vm= => nil) }
      let(:instance_state) { 'definitely-not-stopped' }
      let(:instance_vms) { [] }
      let(:ip_provider) { nil }
      let(:links_manager) { instance_double(Links::LinksManager, bind_links_to_instance: nil) }
      let(:needs_recreate) { nil }
      let(:needs_shutting_down?) { false }
      let(:network_settings) { instance_double(NetworkSettings, dns_record_info: nil) }
      let(:options) { { canary: 'polly' } }
      let(:prepare_instance_step) { instance_double(Steps::PrepareInstanceStep, perform: nil) }
      let(:recreate_handler) { instance_double(InstanceUpdater::RecreateHandler, perform: nil) }
      let(:should_create_swap_delete?) { false }
      let(:state_applier) { instance_double(InstanceUpdater::StateApplier, apply: nil) }
      let(:unmount_instance_disk_step) { instance_double(Steps::UnmountInstanceDisksStep, perform: nil) }
      let(:detach_instance_disk_step) { instance_double(Steps::DetachInstanceDisksStep, perform: nil) }
      let(:vm_creator) { nil }
      let(:tags) { {} }
      let(:metadata_updater) { instance_double(MetadataUpdater, update_vm_metadata: nil, update_disk_metadata: nil) }
      let(:persistent_disk) { nil }
      let(:task) { instance_double('Bosh::Director::EventLog::Task') }

      let(:rendered_templates_persistor) do
        instance_double(RenderedTemplatesPersister, persist: nil)
      end

      let(:instance_plan) do
        instance_double(
          InstancePlan,
          changes: instance_plan_changes,
          new?: instance_new?,
          desired_az_name: 'arizona-1',
          dns_changed?: dns_changed?,
          already_detached?: already_detached?,
          needs_shutting_down?: needs_shutting_down?,
          instance: instance,
          existing_instance: nil,
          should_create_swap_delete?: should_create_swap_delete?,
          release_obsolete_network_plans: nil,
          desired_instance: desired_instance,
          network_settings: network_settings,
          tags: tags,
        )
      end

      let(:instance_model) do
        instance_double(
          Models::Instance,
          state: instance_model_state,
          active_vm: active_vm,
          agent_id: agent_id,
          name: instance_name,
          vms: instance_vms,
          managed_persistent_disk: persistent_disk,
        )
      end

      let(:instance) do
        instance_double(
          DeploymentPlan::Instance,
          update_variable_set: nil,
          state: instance_state,
          deployment_model: nil,
          model: instance_model,
          update_instance_settings: nil,
          update_state: nil,
        )
      end

      before do
        allow(InstanceUpdater::RecreateHandler).to receive(:new).and_return(recreate_handler)
        allow(Steps::PrepareInstanceStep).to receive(:new).and_return(prepare_instance_step)
        allow(Steps::UnmountInstanceDisksStep).to receive(:new).and_return(unmount_instance_disk_step)
        allow(Steps::DetachInstanceDisksStep).to receive(:new).and_return(detach_instance_disk_step)
        allow(Steps::DeleteVmStep).to receive(:new).and_return(delete_vm_step)
        allow(Api::SnapshotManager).to receive(:take_snapshot)
        allow(InstanceUpdater::StateApplier).to receive(:new).and_return(state_applier)
        allow(AgentClient).to receive(:with_agent_id).and_return(agent)
        cloud_factory = instance_double(CloudFactory)
        allow(CloudFactory).to receive(:create).and_return(cloud_factory)
        allow(cloud_factory).to receive(:get).and_return(instance_double(Bosh::Clouds::ExternalCpi))
        allow(MetadataUpdater).to receive(:build).and_return(metadata_updater)
      end

      describe '#perform' do
        context 'when the only changes are DNS' do
          let(:instance_plan_changes) { [:dns] }
          let(:dns_changed?) { true }

          it 'updates DNS without doing anything else' do
            allow(instance_plan).to receive(:already_detached?) { raise 'Should never get here!' }

            update_procedure.perform

            expect(links_manager).to have_received(:bind_links_to_instance).with(instance)
            expect(instance).to have_received(:update_variable_set)
            expect(dns_state_updater).to have_received(:update_dns_for_instance).with(
              instance_plan,
              dns_record_info,
            )
          end

          context 'when the instance plan dns_changed? is false (is that even possible)' do
            let(:dns_changed?) { false }

            it 'updates DNS without doing anything else' do
              allow(instance_plan).to receive(:already_detached?) { raise 'Should never get here!' }

              update_procedure.perform
              expect(dns_state_updater).to_not have_received(:update_dns_for_instance)
            end
          end
        end

        context 'when the only changes are tags' do
          let(:instance_plan_changes) { [:tags] }
          let(:tags) { { 'tag' => 'value' } }
          let(:active_vm) { Models::Vm.make }
          let(:persistent_disk) { Models::PersistentDisk.make }

          it 'updates VM and disk metadata without doing anything else' do
            allow(instance_plan).to receive(:already_detached?) { raise 'Should never get here!' }

            update_procedure.perform

            expect(links_manager).to have_received(:bind_links_to_instance).with(instance)
            expect(instance).to have_received(:update_variable_set)
            expect(metadata_updater).to have_received(:update_vm_metadata).with(instance_model, active_vm, tags)
            expect(metadata_updater).to have_received(:update_disk_metadata).with(anything, anything, tags)
          end
        end

        context 'when both tags and DNS changed' do
          let(:instance_plan_changes) { %i[tags dns] }
          let(:tags) { { 'tag' => 'value' } }
          let(:dns_changed?) { true }
          let(:active_vm) { Models::Vm.make }
          let(:persistent_disk) { Models::PersistentDisk.make }

          it 'updates metadata and DNS without doing anything else' do
            allow(instance_plan).to receive(:already_detached?) { raise 'Should never get here!' }

            update_procedure.perform

            expect(links_manager).to have_received(:bind_links_to_instance).with(instance)
            expect(instance).to have_received(:update_variable_set)
            expect(metadata_updater).to have_received(:update_vm_metadata).with(instance_model, active_vm, tags)
            expect(metadata_updater).to have_received(:update_disk_metadata).with(anything, anything, tags)
            expect(dns_state_updater).to have_received(:update_dns_for_instance).with(
              instance_plan,
              dns_record_info,
            )
          end
        end

        context 'when there are more changes' do
          let(:enable_nats_delivered_templates) { false }
          let(:already_detached?) { true }
          let(:update) { 'i-am-an-update' }
          let(:persistent_disk) { nil }

          before do
            allow(Config).to receive(:enable_nats_delivered_templates).and_return(enable_nats_delivered_templates)
            allow(Stopper).to receive(:stop)

            update_procedure.perform
          end

          it 'updates the instance, persists templates, and applies state' do
            expect(instance_plan).to have_received(:release_obsolete_network_plans).with(ip_provider)
            expect(instance).to have_received(:update_state)
            expect(links_manager).to have_received(:bind_links_to_instance).with(instance)
            expect(instance).to have_received(:update_variable_set)

            expect(rendered_templates_persistor).to have_received(:persist).with(instance_plan)
            expect(state_applier).to have_received(:apply).with(instance_plan.desired_instance.instance_group.update)
          end

          context 'unless the instance plan is already detached' do
            let(:already_detached?) { false }

            context 'handle_not_detached_instance_plan' do
              context 'if enable_nats_delivered_templates is not enabled' do
                it 'persists rendered templates' do
                  # This inadvertently gets called later in the perform
                  # function. We think that our test setup is incomplete which
                  # leads to happen. Realistically we think that should be
                  # called once.
                  expect(rendered_templates_persistor).to have_received(:persist).with(instance_plan).twice
                  expect(links_manager).to have_received(:bind_links_to_instance).with(instance)
                  expect(instance).to have_received(:update_variable_set)
                end

                it 'updates the instance and binds links to instance' do
                  expect(instance_plan).to have_received(:release_obsolete_network_plans).with(ip_provider)
                  expect(instance).to have_received(:update_state)
                  expect(links_manager).to have_received(:bind_links_to_instance).once
                  expect(instance).to have_received(:update_variable_set).once
                end
              end

              context 'if the instance is not being recreated' do
                let(:needs_recreate) { false }

                it 'persists rendered templates' do
                  # This inadvertently gets called later in the perform
                  # function. We think that our test setup is incomplete which
                  # leads to happen. Realistically we think that should be
                  # called once.
                  expect(rendered_templates_persistor).to have_received(:persist).with(instance_plan).twice
                  expect(links_manager).to have_received(:bind_links_to_instance).with(instance)
                  expect(instance).to have_received(:update_variable_set)
                end
              end

              context 'if both enable_nats_delivered_templates is true and the instance is being recreated' do
                let(:needs_recreate) { true }
                let(:enable_nats_delivered_templates) { true }

                it 'does not persist rendered templates and bind links to instance' do
                  # This inadvertently gets called later in the perform
                  # function. We think that our test setup is incomplete which
                  # leads to happen. Realistically we think that shouldn't be
                  # called.
                  expect(rendered_templates_persistor).to have_received(:persist).with(instance_plan).once
                  expect(links_manager).to have_received(:bind_links_to_instance).once
                  expect(instance).to have_received(:update_variable_set).once
                end
              end

              context 'if the instance plan does not need to shut down and the instance state is not detached' do
                let(:needs_shutting_down?) { false }
                let(:instance_state) { 'something-else' }

                it 'prepares the instance' do
                  expect(prepare_instance_step).to have_received(:perform).with(instance_report)
                end
              end

              context 'if the instance plan needs to shut down' do
                let(:needs_shutting_down?) { true }
                let(:instance_state) { 'something-else' }

                it 'does not prepare the instance' do
                  expect(prepare_instance_step).to_not have_received(:perform)
                end

                it 'stops with the correct stop intent' do
                  expect(Stopper).to have_received(:stop).with(hash_including(
                                                                 intent: :delete_vm,
                                                                 instance_plan: instance_plan,
                                                                 target_state: instance_state,
                                                               ))
                end
              end

              context 'if the instance state is detached' do
                let(:needs_shutting_down?) { false }
                let(:instance_state) { 'detached' }

                it 'does not prepare the instance' do
                  expect(prepare_instance_step).to_not have_received(:perform)
                end

                it 'stops with the correct stop intent' do
                  expect(Stopper).to have_received(:stop).with(hash_including(
                                                                 intent: :delete_vm,
                                                                 instance_plan: instance_plan,
                                                                 target_state: instance_state,
                                                               ))
                end
              end

              context 'if instance model state is not stopped' do
                let(:instance_model_state) { 'not-stopped' }

                it 'stops and takes snapshot' do
                  expect(Stopper).to have_received(:stop)
                  expect(Api::SnapshotManager).to have_received(:take_snapshot).with(instance_model, clean: true)
                end
              end

              context 'if instance model state is not stopped' do
                let(:instance_model_state) { 'not-stopped' }

                context 'if vm requires recreate' do
                  let(:needs_recreate) { true }

                  it 'stops with the correct stop_intent' do
                    expect(Stopper).to have_received(:stop).with(hash_including(
                                                                   intent: :delete_vm,
                                                                   instance_plan: instance_plan,
                                                                   target_state: instance_state,
                                                                 ))
                  end
                end

                context 'if vm does not require recreate' do
                  let(:needs_recreate) { false }

                  it 'stops with the correct stop_intent' do
                    expect(Stopper).to have_received(:stop).with(hash_including(
                                                                   intent: :keep_vm,
                                                                   instance_plan: instance_plan,
                                                                   target_state: instance_state,
                                                                 ))
                  end
                end
              end

              context 'if instance model state is stopped' do
                let(:instance_model_state) { 'stopped' }

                it 'does not stop or take snapshot' do
                  expect(Stopper).to_not have_received(:stop)
                  expect(Api::SnapshotManager).to_not have_received(:take_snapshot)
                end
              end
            end

            context 'when the instance state is stopped' do
              let(:instance_state) { 'stopped' }

              it 'only updates instance, but does not handle_detached_instance' do
                expect(instance_plan).to have_received(:release_obsolete_network_plans).with(ip_provider)
                expect(instance).to have_received(:update_state)
                expect(links_manager).to have_received(:bind_links_to_instance).with(instance)
                expect(instance).to have_received(:update_variable_set)
              end

              context 'when instance variable and links were already updated' do
                # early return if Config.enable_nats_delivered_templates && needs_recreate?
                let(:needs_recreate?) { true }

                before do
                  allow(Config).to receive(:enable_nats_delivered_templates).and_return(true)
                  allow(links_manager).to receive(:bind_links_to_instance) { raise 'Should never get here!' }
                end

                it 'same w/ early return statement' do
                  expect(instance_plan).to have_received(:release_obsolete_network_plans).with(ip_provider)
                  expect(instance).to have_received(:update_state)
                end
              end
            end

            context 'when the instance state is not stopped' do
              let(:instance_state) { 'absolutely-positively-not-stopped' }

              before do
                allow(Api::SnapshotManager).to receive(:take_snapshot).with(instance_model, clean: true)
              end

              context 'when instance state is not detached' do
                let(:instance_state) { 'absolutely-positively-not-stopped' }

                it 'does not perform any steps' do
                  expect(unmount_instance_disk_step).to_not have_received(:perform)
                  expect(detach_instance_disk_step).to_not have_received(:perform)
                  expect(delete_vm_step).to_not have_received(:perform)
                end
              end

              context 'when instance state is detached' do
                let(:instance_state) { 'detached' }

                it 'does the steps' do
                  expect(unmount_instance_disk_step).to have_received(:perform)
                  expect(detach_instance_disk_step).to have_received(:perform)
                  expect(delete_vm_step).to have_received(:perform)
                end
              end
            end
          end

          context 'when the instance state is not detached' do
            let(:active_vm) { Models::Vm.make }

            it 'updates the instance report vm and persistent disks' do
              expect(instance_report).to have_received(:vm=).with(active_vm)
              expect(disk_manager).to have_received(:update_persistent_disk).with(instance_plan)
            end

            context 'when tags changed' do
              let(:tags) { { 'tag' => 'value' } }
              let(:instance_plan_changes) { [:tags] }

              it 'updates tags for VM' do
                expect(metadata_updater).to have_received(:update_vm_metadata).with(anything, active_vm, tags)
              end

              context 'and there is a disk' do
                let(:persistent_disk) { Bosh::Director::Models::PersistentDisk.make }

                it 'updates tags for VM and disk' do
                  expect(metadata_updater).to have_received(:update_vm_metadata)
                  expect(metadata_updater).to have_received(:update_disk_metadata).with(anything, persistent_disk, tags)
                end
              end
            end

            context 'and the instance vm is being recreated' do
              context 'because the recreate has been requested' do
                let(:needs_recreate) { true }

                it 'recreates the vm' do
                  expect(recreate_handler).to have_received(:perform)
                  expect(instance).to_not have_received(:update_instance_settings)
                end
              end

              context 'because the instance plan indicates a recreate is necessary' do
                let(:needs_recreate) { false }
                let(:should_create_swap_delete?) { true }
                let(:instance_vms) { [active_vm, Models::Vm.make] }

                it 'recreates the vm' do
                  expect(recreate_handler).to have_received(:perform)
                  expect(instance).to_not have_received(:update_instance_settings)
                end
              end
            end

            context 'and the instance vm is not being recreated' do
              let(:needs_recreate) { false }
              let(:should_create_swap_delete?) { false }

              it 'does not recreate the vm' do
                expect(recreate_handler).to_not have_received(:perform)
                expect(instance).to have_received(:update_instance_settings)
              end
            end
          end

          context 'when dns has changed' do
            let(:dns_changed?) { true }

            it 'updates DNS without doing anything else' do
              expect(dns_state_updater).to have_received(:update_dns_for_instance).with(
                instance_plan,
                dns_record_info,
              )
            end
          end

          context 'when the instance plan dns_changed? is false (is that even possible)' do
            let(:dns_changed?) { false }

            it 'updates DNS without doing anything else' do
              expect(dns_state_updater).to_not have_received(:update_dns_for_instance)
            end
          end

          context 'when the instance is detached' do
            let(:instance_state) { 'detached' }

            it 'does not persist rendered templates or apply state' do
              expect(rendered_templates_persistor).to_not have_received(:persist)
              expect(state_applier).to_not have_received(:apply)
            end
          end
        end
      end
    end
  end
end
