require 'spec_helper'

module Bosh
  module Director
    describe VmCreator do
      subject(:vm_creator) { VmCreator.new(logger, template_blob_cache, dns_encoder, agent_broadcaster, link_provider_intents) }

      let(:link_provider_intents) { [] }
      let(:vm_deleter) { VmDeleter.new(logger, false, false) }
      let(:template_blob_cache) { instance_double(Bosh::Director::Core::Templates::TemplateBlobCache) }
      let(:agent_broadcaster) { instance_double(AgentBroadcaster) }
      let(:deployment) { Models::Deployment.make(name: 'deployment_name') }
      let(:availability_zone) do
        Bosh::Director::DeploymentPlan::AvailabilityZone.new('az-1', {})
      end
      let(:dns_encoder) { instance_double(DnsEncoder) }
      let(:ip_provider) { double(:ip_provider) }

      let(:instance) do
        instance_double(DeploymentPlan::Instance, model: instance_model, vm_created?: false)
      end
      let(:reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, manual_network) }
      let(:instance_plan) do
        desired_instance = Bosh::Director::DeploymentPlan::DesiredInstance.new(instance_group)
        network_plan = Bosh::Director::DeploymentPlan::NetworkPlanner::Plan.new(reservation: reservation)
        Bosh::Director::DeploymentPlan::InstancePlan.new(
          existing_instance: instance_model,
          desired_instance: desired_instance,
          instance: instance,
          network_plans: [network_plan],
          variables_interpolator: nil,
        )
      end

      let(:tags) { { 'mytag' => 'foobar', 'secondtag' => 'overwriteme' } }
      let(:expected_merged_tags) { { 'mytag' => 'foobar', 'secondtag' => 'overwritten', 'instance_tag' => 'buzz' } }

      let(:instance_group) do
        disk = DeploymentPlan::PersistentDiskCollection.new(logger)
        disk.add_by_disk_size(1024)
        instance_group_tags = { 'instance_tag' => 'buzz', 'secondtag' => 'overwritten' }
        FactoryBot.build(:deployment_plan_instance_group,
          persistent_disk_collection: disk,
          tags: instance_group_tags,
        )
      end

      let(:instance_model) do
        Models::Instance.make(
          index: 5,
          deployment: deployment,
          job: 'fake-job',
          availability_zone: 'az1',
        )
      end

      let(:networks) do
        { 'my-manual-network' => manual_network }
      end
      let(:manual_network_spec) do
        {
          'name' => 'my-manual-network',
          'subnets' => [
            {
              'range' => '192.168.1.0/30',
              'gateway' => '192.168.1.1',
              'dns' => ['192.168.1.1', '192.168.1.2'],
              'static' => [],
              'reserved' => [],
              'cloud_properties' => {},
              'az' => 'az-1',
            },
          ],
        }
      end
      let(:manual_network) do
        DeploymentPlan::ManualNetwork.parse(
          manual_network_spec,
          [Bosh::Director::DeploymentPlan::AvailabilityZone.new('az-1', {})],
          logger,
        )
      end

      let(:spec_apply_step) { instance_double(DeploymentPlan::Steps::ApplyVmSpecStep, perform: nil) }
      let(:create_vm_step) { instance_double(DeploymentPlan::Steps::CreateVmStep, perform: nil) }
      let(:update_settings_step) { instance_double(DeploymentPlan::Steps::UpdateInstanceSettingsStep, perform: nil) }
      let(:elect_active_vm_step) { instance_double(DeploymentPlan::Steps::ElectActiveVmStep, perform: nil) }
      let(:render_step) { instance_double(DeploymentPlan::Steps::RenderInstanceJobTemplatesStep, perform: nil) }
      let(:attach_instance_disks_step) { instance_double(DeploymentPlan::Steps::AttachInstanceDisksStep, perform: nil) }
      let(:mount_instance_disks_step) { instance_double(DeploymentPlan::Steps::MountInstanceDisksStep, perform: nil) }
      let(:commit_networks_step) { instance_double(DeploymentPlan::Steps::CommitInstanceNetworkSettingsStep, perform: nil) }
      let(:release_networks_step) { instance_double(DeploymentPlan::Steps::ReleaseObsoleteNetworksStep, perform: nil) }

      let!(:report) { DeploymentPlan::Stages::Report.new }

      before do
        fake_app

        allow(instance_model).to receive(:managed_persistent_disk_cid).and_return('fake-disk-cid')
        allow(DeploymentPlan::Stages::Report).to receive(:new).and_return(report)

        allow(DeploymentPlan::Steps::CreateVmStep).to receive(:new)
          .with(
            instance_plan,
            agent_broadcaster,
            ['fake-disk-cid'],
            expected_merged_tags,
            false,
          ).and_return(create_vm_step)
        allow(DeploymentPlan::Steps::UpdateInstanceSettingsStep).to receive(:new)
          .with(instance_plan).and_return(update_settings_step)
        allow(DeploymentPlan::Steps::ElectActiveVmStep).to receive(:new)
          .and_return(elect_active_vm_step)
        allow(DeploymentPlan::Steps::ApplyVmSpecStep).to receive(:new).and_return(spec_apply_step)
        allow(DeploymentPlan::Steps::RenderInstanceJobTemplatesStep).to receive(:new)
          .with(instance_plan, template_blob_cache, dns_encoder, link_provider_intents).and_return(render_step)
        allow(DeploymentPlan::Steps::AttachInstanceDisksStep).to receive(:new)
          .with(instance_model, expected_merged_tags).and_return(attach_instance_disks_step)
        allow(DeploymentPlan::Steps::MountInstanceDisksStep).to receive(:new)
          .with(instance_model).and_return(mount_instance_disks_step)
        allow(DeploymentPlan::Steps::CommitInstanceNetworkSettingsStep).to receive(:new)
          .and_return(commit_networks_step)
        allow(DeploymentPlan::Steps::ReleaseObsoleteNetworksStep).to receive(:new)
          .with(ip_provider).and_return(release_networks_step)
      end

      describe '#create_for_instance_plan' do
        it 'runs steps in the correct order' do
          expect(create_vm_step).to receive(:perform).with(report).ordered
          expect(elect_active_vm_step).to receive(:perform).with(report).ordered
          expect(commit_networks_step).to receive(:perform).with(report).ordered
          expect(release_networks_step).to receive(:perform).with(report).ordered
          expect(attach_instance_disks_step).to receive(:perform).with(report).ordered
          expect(mount_instance_disks_step).to receive(:perform).with(report).ordered
          expect(update_settings_step).to receive(:perform).with(report).ordered
          expect(spec_apply_step).to receive(:perform).with(report).ordered
          expect(render_step).to receive(:perform).with(report).ordered

          vm_creator.create_for_instance_plan(instance_plan, ip_provider, ['fake-disk-cid'], tags)
        end

        it 're-renders job templates after applying spec' do
          expect(create_vm_step).to receive(:perform).with(report).ordered
          expect(spec_apply_step).to receive(:perform).with(report).ordered
          expect(render_step).to receive(:perform).with(report)

          vm_creator.create_for_instance_plan(instance_plan, ip_provider, ['fake-disk-cid'], tags)
        end

        context 'when instance already has associated active_vm' do
          before { allow(instance).to receive(:vm_created?).and_return(true) }

          it 'does not run the elect active vm step' do
            expect(create_vm_step).to receive(:perform).with(report)
            expect(elect_active_vm_step).not_to receive(:perform)

            vm_creator.create_for_instance_plan(instance_plan, ip_provider, ['fake-disk-cid'], tags)
          end
        end

        context 'when the instance plan does not need a persistent disk' do
          before do
            allow(instance_plan).to receive(:needs_disk?).and_return(false)
          end

          it 'does not try to attach the disk' do
            expect(create_vm_step).to receive(:perform).with(report)
            expect(attach_instance_disks_step).not_to receive(:perform)
            expect(mount_instance_disks_step).not_to receive(:perform)

            vm_creator.create_for_instance_plan(instance_plan, ip_provider, ['fake-disk-cid'], tags)
          end
        end

        context 'when the instance plan needs a persistent disk' do
          before do
            allow(instance_plan).to receive(:needs_disk?).and_return(true)
          end

          context 'when the instance uses legacy updating instance strategy' do
            it 'adds attach and mount disk steps' do
              expect(create_vm_step).to receive(:perform).with(report)
              expect(attach_instance_disks_step).to receive(:perform)
              expect(mount_instance_disks_step).to receive(:perform)

              vm_creator.create_for_instance_plan(instance_plan, ip_provider, ['fake-disk-cid'], tags)
            end
          end

          context 'when the instance uses create-swap-delete strategy' do
            before do
              allow(instance_plan).to receive(:should_create_swap_delete?).and_return(true)
            end

            context 'when there is already an active vm' do
              before { allow(instance).to receive(:vm_created?).and_return(true) }

              it 'does NOT add attach and mount disk steps' do
                expect(create_vm_step).to receive(:perform).with(report)
                expect(attach_instance_disks_step).not_to receive(:perform)
                expect(mount_instance_disks_step).not_to receive(:perform)

                vm_creator.create_for_instance_plan(instance_plan, ip_provider, ['fake-disk-cid'], tags)
              end
            end

            context 'when there is no active vm' do
              it 'adds attach and mount disk steps' do
                expect(create_vm_step).to receive(:perform).with(report)
                expect(attach_instance_disks_step).to receive(:perform)
                expect(mount_instance_disks_step).to receive(:perform)

                vm_creator.create_for_instance_plan(instance_plan, ip_provider, ['fake-disk-cid'], tags)
              end
            end
          end
        end
      end

      describe '#create_for_instance_plans' do
        let(:ip_repo) { DeploymentPlan::IpRepo.new(logger) }
        let(:ip_provider) { DeploymentPlan::IpProvider.new(ip_repo, networks, logger) }

        it 'creates vms for the given instance plans' do
          expect(create_vm_step).to receive(:perform).with(report)

          expect(attach_instance_disks_step).to receive(:perform).with(report).once
          expect(mount_instance_disks_step).to receive(:perform).with(report).once
          expect(update_settings_step).to receive(:perform).with(report)

          vm_creator.create_for_instance_plans([instance_plan], ip_provider, tags)
        end
      end
    end
  end
end
