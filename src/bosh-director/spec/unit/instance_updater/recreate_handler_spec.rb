require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe InstanceUpdater::RecreateHandler do
      describe '#perform' do
        let(:cids) { ['bobcid'] }
        let(:ip_address) { FactoryBot.create(:models_ip_address) }
        let(:active_vm) do
          double(
            Models::Vm,
            id: 1,
            ip_addresses: [ip_address],
          )
        end
        let(:inactive_vm) { double(Models::Vm, id: 2) }

        let(:vms) { [active_vm, inactive_vm] }
        let(:instance_model) do
          instance_double(
            Models::Instance,
            most_recent_inactive_vm: inactive_vm,
            active_vm: active_vm,
            vms: vms,
            active_persistent_disk_cids: cids,
          )
        end

        let(:instance) do
          instance_double(
            Instance,
            model: instance_model,
            update_instance_settings: true,
          )
        end

        let(:logger) { double(Logging::Logger, debug: 'ok') }
        let(:vm_creator) { double(VmCreator, create_for_instance_plan: nil) }
        let(:ip_provider) { nil }
        let(:needs_disk?) { false }
        let(:tags) { 'bobtags' }
        let(:should_create_swap_delete?) { true }
        let(:instance_plan) do
          double(
            InstancePlan,
            instance: instance,
            unresponsive_agent?: agent_unresponsive?,
            should_create_swap_delete?: should_create_swap_delete?,
            remove_obsolete_network_plans_for_ips: nil,
            needs_disk?: needs_disk?,
            tags: tags,
          )
        end
        let(:instance_report) do
          double(Stages::Report, :vm= => nil, vm: inactive_vm)
        end

        let(:disk_step) { double(Steps::UnmountInstanceDisksStep, perform: nil) }
        let(:elect_step) { double(Steps::ElectActiveVmStep, perform: nil) }
        let(:detach_instance_disks_step) { double(Steps::DetachInstanceDisksStep, perform: nil) }
        let(:attach_instance_disks_step) { double(Steps::AttachInstanceDisksStep, perform: nil) }
        let(:mount_instance_disks_step) { double(Steps::MountInstanceDisksStep, perform: nil) }
        let(:unmount_instance_disks_step) { double(Steps::UnmountInstanceDisksStep, perform: nil) }
        let(:orphan_step) { double(Steps::OrphanVmStep, perform: nil) }
        let(:delete_vm_step) { double(Steps::DeleteVmStep, perform: nil) }

        before do
          allow(Steps::UnmountInstanceDisksStep).to receive(:new).with(instance_model).and_return(disk_step)
          allow(Steps::ElectActiveVmStep).to receive(:new).and_return(elect_step)
          allow(Steps::MountInstanceDisksStep).to receive(:new).with(instance_model).and_return(mount_instance_disks_step)
          allow(Steps::UnmountInstanceDisksStep).to receive(:new).with(instance_model).and_return(unmount_instance_disks_step)
          allow(Steps::DetachInstanceDisksStep).to receive(:new).with(instance_model).and_return(detach_instance_disks_step)
          allow(Steps::AttachInstanceDisksStep).to receive(:new).with(instance_model, tags).and_return(attach_instance_disks_step)
          allow(Steps::OrphanVmStep).to receive(:new).with(active_vm).and_return(orphan_step)
          allow(Steps::DeleteVmStep).to receive(:new).with(true, false, nil).and_return(delete_vm_step)
        end

        subject(:recreate_handler) do
          InstanceUpdater::RecreateHandler.new(
            logger,
            vm_creator,
            ip_provider,
            instance_plan,
            instance_report,
            instance,
          )
        end

        context 'when the agent is responsive' do
          let(:agent_unresponsive?) { false }

          context 'when it does create swap delete' do
            let(:inactive_vm) { double(Models::Vm, id: 2) }

            before do
              recreate_handler.perform
            end

            it 'elects new vm' do
              expect(elect_step).to have_received(:perform).with(instance_report)
            end

            it 'orphans' do
              expect(orphan_step).to have_received(:perform).with(instance_report)
              expect(instance_plan).to have_received(:remove_obsolete_network_plans_for_ips).with([ip_address.address_str])
            end

            it 'updates instance settings' do
              expect(instance).to have_received(:update_instance_settings).with(instance.model.active_vm)
            end

            context 'when it needs a disk' do
              let(:needs_disk?) { true }

              it 'attaches and detaches' do
                expect(attach_instance_disks_step).to have_received(:perform).with(instance_report)
                expect(mount_instance_disks_step).to have_received(:perform).with(instance_report)
              end
            end

            context 'when it needs no disk' do
              let(:needs_disk?) { false }

              it 'does not' do
                expect(attach_instance_disks_step).to_not have_received(:perform).with(instance_report)
                expect(mount_instance_disks_step).to_not have_received(:perform).with(instance_report)
              end
            end
          end

          context 'when it does not create swap delete' do
            let(:should_create_swap_delete?) { false }

            it 'creates a VM' do
              recreate_handler.perform

              expect(vm_creator).to have_received(:create_for_instance_plan).with(
                instance_plan,
                ip_provider,
                cids,
                tags,
              )
            end

            context 'when it has not deleted a VM (i.e. agent was not unresponsive)' do
              it 'deletes vm' do
                recreate_handler.perform
                expect(delete_vm_step).to have_received(:perform)
              end
            end
          end
        end

        context 'when the agent is unresponsive' do
          let(:agent_unresponsive?) { true }

          context 'when not create swap deleting' do
            let(:should_create_swap_delete?) { false }

            it 'deletes VM only once' do
              recreate_handler.perform
              expect(delete_vm_step).to have_received(:perform).once
            end
          end

          context 'when create swap deleting' do
            let(:should_create_swap_delete?) { true }

            it 'deletes VM only once' do
              recreate_handler.perform
              expect(delete_vm_step).to have_received(:perform).once
            end
          end
        end
      end
    end
  end
end
