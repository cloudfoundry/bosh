require 'spec_helper'

module Bosh::Director
  describe Jobs::DynamicDisks::AttachDynamicDisk do
    let(:disk_name) { 'fake-disk-name' }
    let(:disk_cid) { 'fake-disk-cid' }
    let(:disk_hint) { { 'id' => 'fake-disk-id' } }
    let(:metadata) { nil }

    let(:agent_client) { instance_double(AgentClient) }
    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }

    let(:instance) { FactoryBot.create(:models_instance) }
    let!(:vm) { FactoryBot.create(:models_vm, instance: instance, active: true) }

    let(:attach_dynamic_disk_job) { Jobs::DynamicDisks::AttachDynamicDisk.new(disk_name, instance.uuid, metadata) }
    let(:cloud_factory) { instance_double(CloudFactory, get: cloud) }

    before do
      allow(Config).to receive(:name).and_return('fake-director-name')
      allow(Config).to receive(:cloud_options).and_return('provider' => { 'path' => '/path/to/default/cpi' })
      allow(Config).to receive(:preferred_cpi_api_version).and_return(2)
      allow(CloudFactory).to receive(:create).and_return(cloud_factory)
      allow(AgentClient).to receive(:with_agent_id).with(vm.agent_id, instance.name).and_return(agent_client)
      allow(cloud).to receive(:respond_to?).with(:set_disk_metadata).and_return(false)
    end

    describe 'DJ job class expectations' do
      let(:job_type) { :attach_dynamic_disk }
      let(:queue) { :dynamic_disks }
      it_behaves_like 'a DelayedJob job'
    end

    describe '#perform' do
      context 'when disk exists and is not attached' do
        let!(:disk) do
          FactoryBot.create(
            :models_dynamic_disk,
            name: disk_name,
            disk_cid: disk_cid,
            deployment: instance.deployment,
          )
        end

        it 'attaches the disk to the VM and notifies the agent' do
          expect(attach_dynamic_disk_job).to receive(:with_vm_lock).with(vm.cid, timeout: Jobs::Helpers::DynamicDiskHelpers::VM_LOCK_TIMEOUT).and_yield
          expect(cloud).to receive(:attach_disk).with(vm.cid, disk_cid).and_return(disk_hint)
          expect(agent_client).to receive(:add_dynamic_disk).with(disk_cid, disk_hint)

          result = attach_dynamic_disk_job.perform

          expect(result).to eq("attached disk `#{disk_name}` to vm `#{vm.cid}` in deployment `#{instance.deployment.name}`")

          disk.reload
          expect(disk.vm).to eq(vm)
          expect(disk.availability_zone).to eq(vm.instance.availability_zone)
        end

        context 'when metadata is provided and CPI supports set_disk_metadata' do
          let(:metadata) { { 'fake-key' => 'fake-value' } }

          it 'sets disk metadata after attaching' do
            expect(attach_dynamic_disk_job).to receive(:with_vm_lock).with(vm.cid, timeout: Jobs::Helpers::DynamicDiskHelpers::VM_LOCK_TIMEOUT).and_yield
            expect(cloud).to receive(:attach_disk).with(vm.cid, disk_cid).and_return(disk_hint)
            expect(cloud).to receive(:respond_to?).with(:set_disk_metadata).and_return(true)
            expect(cloud).to receive(:set_disk_metadata).with(
              disk_cid,
              hash_including('fake-key' => 'fake-value'),
            )
            expect(agent_client).to receive(:add_dynamic_disk).with(disk_cid, disk_hint)

            attach_dynamic_disk_job.perform

            disk.reload
            expect(disk.metadata).to eq(metadata)
          end
        end

        context 'when metadata is nil' do
          let(:metadata) { nil }

          it 'does not call set_disk_metadata' do
            expect(attach_dynamic_disk_job).to receive(:with_vm_lock).with(vm.cid, timeout: Jobs::Helpers::DynamicDiskHelpers::VM_LOCK_TIMEOUT).and_yield
            expect(cloud).to receive(:attach_disk).with(vm.cid, disk_cid).and_return(disk_hint)
            expect(cloud).not_to receive(:set_disk_metadata)
            expect(agent_client).to receive(:add_dynamic_disk).with(disk_cid, disk_hint)

            attach_dynamic_disk_job.perform
          end
        end
      end

      context 'when disk is already attached to the same VM' do
        let!(:disk) do
          FactoryBot.create(
            :models_dynamic_disk,
            name: disk_name,
            disk_cid: disk_cid,
            deployment: instance.deployment,
            vm: vm,
          )
        end

        it 'returns a success message without re-attaching (idempotent)' do
          expect(cloud).not_to receive(:attach_disk)
          expect(agent_client).not_to receive(:add_dynamic_disk)

          result = attach_dynamic_disk_job.perform

          expect(result).to eq("disk `#{disk_name}` is already attached to vm `#{vm.cid}`")
        end
      end

      context 'when disk is already attached to a different VM' do
        let(:other_instance) { FactoryBot.create(:models_instance) }
        let!(:other_vm) { FactoryBot.create(:models_vm, instance: other_instance, active: true) }
        let!(:disk) do
          FactoryBot.create(
            :models_dynamic_disk,
            name: disk_name,
            disk_cid: disk_cid,
            deployment: instance.deployment,
            vm: other_vm,
          )
        end

        it 'raises an error' do
          expect { attach_dynamic_disk_job.perform }.to raise_error(
            "disk `#{disk_name}` is already attached to a different vm `#{other_vm.cid}`",
          )
        end
      end

      context 'AZ mismatch between disk and target VM' do
        let!(:disk) do
          FactoryBot.create(
            :models_dynamic_disk,
            name: disk_name,
            disk_cid: disk_cid,
            deployment: instance.deployment,
            availability_zone: 'z1',
          )
        end

        before do
          allow(instance).to receive(:availability_zone).and_return('z2')
          instance.update(availability_zone: 'z2')
        end

        it 'raises an error when disk AZ does not match VM AZ' do
          expect { attach_dynamic_disk_job.perform }.to raise_error(
            /disk `#{disk_name}` is in AZ `z1` but instance `#{instance.uuid}` is in AZ `z2`/,
          )
        end
      end

      context 'AZ match between disk and target VM' do
        let!(:disk) do
          FactoryBot.create(
            :models_dynamic_disk,
            name: disk_name,
            disk_cid: disk_cid,
            deployment: instance.deployment,
            availability_zone: instance.availability_zone,
          )
        end

        it 'attaches successfully when AZs match' do
          expect(attach_dynamic_disk_job).to receive(:with_vm_lock).with(vm.cid, timeout: Jobs::Helpers::DynamicDiskHelpers::VM_LOCK_TIMEOUT).and_yield
          expect(cloud).to receive(:attach_disk).with(vm.cid, disk_cid).and_return(disk_hint)
          expect(agent_client).to receive(:add_dynamic_disk).with(disk_cid, disk_hint)

          expect { attach_dynamic_disk_job.perform }.not_to raise_error
        end
      end

      context 'when disk has no AZ set (created before AZ tracking)' do
        let!(:disk) do
          FactoryBot.create(
            :models_dynamic_disk,
            name: disk_name,
            disk_cid: disk_cid,
            deployment: instance.deployment,
            availability_zone: nil,
          )
        end

        it 'skips AZ check and attaches successfully' do
          expect(attach_dynamic_disk_job).to receive(:with_vm_lock).with(vm.cid, timeout: Jobs::Helpers::DynamicDiskHelpers::VM_LOCK_TIMEOUT).and_yield
          expect(cloud).to receive(:attach_disk).with(vm.cid, disk_cid).and_return(disk_hint)
          expect(agent_client).to receive(:add_dynamic_disk).with(disk_cid, disk_hint)

          expect { attach_dynamic_disk_job.perform }.not_to raise_error
        end
      end

      context 'when disk does not exist' do
        it 'raises an error' do
          expect { attach_dynamic_disk_job.perform }.to raise_error("disk `#{disk_name}` not found")
        end
      end

      context 'when instance cannot be found' do
        let!(:disk) do
          FactoryBot.create(
            :models_dynamic_disk,
            name: disk_name,
            disk_cid: disk_cid,
            deployment: instance.deployment,
          )
        end
        let(:attach_dynamic_disk_job) { Jobs::DynamicDisks::AttachDynamicDisk.new(disk_name, 'unknown-instance-id') }

        it 'raises an error' do
          expect { attach_dynamic_disk_job.perform }.to raise_error("instance `unknown-instance-id` not found")
        end
      end

      context 'when there is no active VM for the instance' do
        let(:vm) { FactoryBot.create(:models_vm, instance: instance, active: false) }
        let!(:disk) do
          FactoryBot.create(
            :models_dynamic_disk,
            name: disk_name,
            disk_cid: disk_cid,
            deployment: instance.deployment,
          )
        end

        it 'raises an error' do
          expect { attach_dynamic_disk_job.perform }.to raise_error("no active vm found for instance `#{instance.uuid}`")
        end
      end
    end
  end
end
