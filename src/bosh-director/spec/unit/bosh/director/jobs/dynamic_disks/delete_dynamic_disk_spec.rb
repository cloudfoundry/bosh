require 'spec_helper'

module Bosh::Director
  describe Jobs::DynamicDisks::DeleteDynamicDisk do
    let(:disk_name) { 'fake-disk-name' }
    let(:disk_cid) { 'fake-disk-cid' }
    let(:disk_pool_name) { 'fake-disk-pool-name' }

    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
    let(:delete_dynamic_disk_job) { Jobs::DynamicDisks::DeleteDynamicDisk.new(disk_name) }
    let!(:vm) { FactoryBot.create(:models_vm) }
    let(:cloud_factory) { instance_double(Bosh::Director::CloudFactory, get: cloud) }

    before do
      allow(Bosh::Director::Config).to receive(:name).and_return('fake-director-name')
      allow(Bosh::Director::Config).to receive(:cloud_options).and_return('provider' => { 'path' => '/path/to/default/cpi' })
      allow(Bosh::Director::Config).to receive(:preferred_cpi_api_version).and_return(2)
      allow(CloudFactory).to receive(:create).and_return(cloud_factory)
      allow(cloud).to receive(:has_disk).and_return(false)
    end

    describe '#perform' do
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

        it 'deletes the disk' do
          expect(delete_dynamic_disk_job.perform).to eq("deleted disk `#{disk_cid}`")
          expect(Models::DynamicDisk.where(disk_cid: disk_cid).count).to eq(0)
        end
      end

      context 'when disk exists in database and in the cloud' do
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
          allow(cloud).to receive(:has_disk).and_return(true)
        end

        it 'deletes the disk' do
          expect(cloud).to receive(:delete_disk).with(disk_cid)
          expect(delete_dynamic_disk_job.perform).to eq("deleted disk `#{disk_cid}`")
          expect(Models::DynamicDisk.where(disk_cid: disk_cid).count).to eq(0)
        end

        context 'when deleting disk returns an error' do
          it 'returns an error from delete_disk call' do
            expect(cloud).to receive(:delete_disk).with(disk_cid).and_raise('some-error')
            expect { delete_dynamic_disk_job.perform }.to raise_error('some-error')
          end
        end
      end

      context 'when disk does not exist' do
        it 'does not delete disk and returns no error' do
          expect(cloud).not_to receive(:delete_disk).with(disk_cid)
          expect(delete_dynamic_disk_job.perform).to eq("disk with name `#{disk_name}` was already deleted")
        end
      end
    end
  end
end
