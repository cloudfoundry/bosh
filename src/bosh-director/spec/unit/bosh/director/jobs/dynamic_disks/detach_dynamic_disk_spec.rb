require 'spec_helper'

module Bosh::Director
  describe Jobs::DynamicDisks::DetachDynamicDisk do
    let(:agent_id) { 'fake-agent-id' }
    let(:reply) { 'inbox.fake' }
    let(:disk_name) { 'fake-disk-name' }
    let(:disk_cid) { 'fake-disk-cid' }
    let(:disk_pool_name) { 'fake-disk-pool-name' }

    let(:nats_rpc) { instance_double(Bosh::Director::NatsRpc) }
    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
    let(:detach_dynamic_disk_job) { Jobs::DynamicDisks::DetachDynamicDisk.new(reply, disk_name) }
    let!(:vm) { FactoryBot.create(:models_vm, agent_id: agent_id, cid: 'fake-vm-cid') }
    let(:cloud_factory) { instance_double(Bosh::Director::CloudFactory, get: cloud) }

    before do
      allow(Config).to receive(:nats_rpc).and_return(nats_rpc)
      allow(Bosh::Director::Config).to receive(:name).and_return('fake-director-name')
      allow(Bosh::Director::Config).to receive(:cloud_options).and_return('provider' => { 'path' => '/path/to/default/cpi' })
      allow(Bosh::Director::Config).to receive(:preferred_cpi_api_version).and_return(2)
      allow(CloudFactory).to receive(:create).and_return(cloud_factory)
      allow(cloud).to receive(:has_disk).and_return(true)
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
            expect(nats_rpc).to receive(:send_message).with(reply, {
              'error' => nil
            })
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
            expect(nats_rpc).to receive(:send_message).with(reply, {
              'error' => nil
            })
            expect(detach_dynamic_disk_job.perform).to eq("detached disk `#{disk_cid}` from vm `#{vm.cid}`")
            expect(Models::DynamicDisk.find(disk_cid: disk_cid).vm_id).to be_nil
          end

          context 'when disk is already detached' do
            it 'returns an error' do
              expect(cloud).to receive(:detach_disk).with(vm.cid, disk_cid).and_raise(Bosh::Clouds::DiskNotAttached.new(false))
              expect(nats_rpc).to receive(:send_message).with(reply, {
                'error' => nil
              })
              expect(detach_dynamic_disk_job.perform).to eq("disk `#{disk_cid}` was already detached")
              expect(Models::DynamicDisk.find(disk_cid: disk_cid).vm_id).to be_nil
            end
          end
        end
      end

      context 'when disk does not exist in database' do
        it 'returns an error' do
          expect(nats_rpc).to receive(:send_message).with(reply, {
            'error' => "disk `#{disk_name}` can not be found in the database"
          })
          expect { detach_dynamic_disk_job.perform }.to raise_error("disk `#{disk_name}` can not be found in the database")
        end
      end

      context 'when disk exists in database but not in the cloud' do
        let!(:disk) do
          FactoryBot.create(
            :models_dynamic_disk,
            name: disk_name,
            disk_cid: disk_cid,
            deployment: vm.instance.deployment,
            disk_pool_name: disk_pool_name
          )
        end

        before do
          allow(cloud).to receive(:has_disk).and_return(false)
        end

        it 'returns an error' do
          expect(nats_rpc).to receive(:send_message).with(reply, {
            'error' => "disk `#{disk_name}` can not be found in the cloud"
          })
          expect { detach_dynamic_disk_job.perform }.to raise_error("disk `#{disk_name}` can not be found in the cloud")
        end
      end
    end
  end
end
