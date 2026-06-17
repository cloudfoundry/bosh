require 'spec_helper'

module Bosh::Director
  describe Jobs::DynamicDisks::AttachDynamicDisk do
    let(:disk_name) { 'fake-disk-name' }
    let(:disk_cid) { 'fake-disk-cid' }
    let(:disk_hint) { { 'id' => 'fake-disk-id' } }

    let(:agent_client) { instance_double(AgentClient) }
    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }

    let(:instance) { FactoryBot.create(:models_instance) }
    let!(:vm) { FactoryBot.create(:models_vm, instance: instance, active: true) }

    let(:attach_dynamic_disk_job) { Jobs::DynamicDisks::AttachDynamicDisk.new(disk_name, instance.uuid) }
    let(:cloud_factory) { instance_double(CloudFactory, get: cloud) }

    before do
      allow(Config).to receive(:name).and_return('fake-director-name')
      allow(Config).to receive(:cloud_options).and_return('provider' => { 'path' => '/path/to/default/cpi' })
      allow(Config).to receive(:preferred_cpi_api_version).and_return(2)
      allow(CloudFactory).to receive(:create).and_return(cloud_factory)
      allow(AgentClient).to receive(:with_agent_id).with(vm.agent_id, instance.name).and_return(agent_client)
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
