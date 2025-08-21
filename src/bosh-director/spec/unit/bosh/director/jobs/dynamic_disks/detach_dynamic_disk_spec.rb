require 'spec_helper'

module Bosh::Director
  describe Jobs::DynamicDisks::DetachDynamicDisk do
    let(:disk_name) { 'fake-disk-name' }
    let(:disk_cid) { 'fake-disk-cid' }
    let(:disk_pool_name) { 'fake-disk-pool-name' }

    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
    let(:agent_client) { instance_double(AgentClient) }
    let(:detach_dynamic_disk_job) { Jobs::DynamicDisks::DetachDynamicDisk.new(disk_name) }
    let!(:vm) { FactoryBot.create(:models_vm, instance: instance) }
    let(:instance) { FactoryBot.create(:models_instance) }
    let(:cloud_factory) { instance_double(Bosh::Director::CloudFactory, get: cloud) }

    before do
      allow(Bosh::Director::Config).to receive(:name).and_return('fake-director-name')
      allow(Bosh::Director::Config).to receive(:cloud_options).and_return('provider' => { 'path' => '/path/to/default/cpi' })
      allow(Bosh::Director::Config).to receive(:preferred_cpi_api_version).and_return(2)
      allow(CloudFactory).to receive(:create).and_return(cloud_factory)
      allow(cloud).to receive(:has_disk).and_return(true)
      allow(AgentClient).to receive(:with_agent_id).with(vm.agent_id, instance.name).and_return(agent_client)
    end

    describe '#perform' do
      context 'when disk exists in database' do
        context 'when disk has no vm assigned' do
          let!(:disk) do
            FactoryBot.create(
              :models_dynamic_disk,
              name: disk_name,
              disk_cid: disk_cid,
              deployment: vm.instance.deployment,
              disk_pool_name: disk_pool_name
            )
          end

          it 'does not detach the disk' do
            expect(detach_dynamic_disk_job.perform).to eq("disk `#{disk_cid}` was already detached")
          end
        end

        context 'when disk has vm assigned' do
          let!(:disk) do
            FactoryBot.create(
              :models_dynamic_disk,
              name: disk_name,
              disk_cid: disk_cid,
              deployment: vm.instance.deployment,
              vm: vm,
              disk_pool_name: disk_pool_name
            )
          end

          it 'detaches the disk' do
            expect(cloud).to receive(:detach_disk).with(vm.cid, disk_cid)
            expect(agent_client).to receive(:remove_dynamic_disk).with(disk_cid)
            expect(detach_dynamic_disk_job.perform).to eq("detached disk `#{disk_cid}` from vm `#{vm.cid}`")
            expect(Models::DynamicDisk.find(disk_cid: disk_cid).vm_id).to be_nil
          end

          context 'when disk is already detached' do
            it 'does not return an error' do
              expect(cloud).to receive(:detach_disk).with(vm.cid, disk_cid).and_raise(Bosh::Clouds::DiskNotAttached.new(false))
              expect(agent_client).to receive(:remove_dynamic_disk).with(disk_cid)
              expect(detach_dynamic_disk_job.perform).to eq("disk `#{disk_cid}` was already detached")
              expect(Models::DynamicDisk.find(disk_cid: disk_cid).vm_id).to be_nil
            end
          end
        end
      end

      context 'when disk does not exist in database' do
        it 'raises an error' do
          expect { detach_dynamic_disk_job.perform }.to raise_error("disk `#{disk_name}` can not be found in the database")
        end
      end
    end
  end
end
