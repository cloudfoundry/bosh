require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe DiskCreator do
    let(:vm_cid) { 'fake-vm-cid' }
    let(:cloud) { Bosh::Director::Config.cloud }
    let(:instance_model) { Bosh::Director::Models::Instance.make(id: 1, vm_cid: vm_cid) }
    let(:disk_creator) { DiskCreator.new(cloud, instance_model) }
    let(:cloud_properties) { { 'fake-property' => 'fake-value' } }

    describe '#create' do
      it 'creates disk' do
        expect(cloud).to receive(:create_disk).with(1234, cloud_properties, vm_cid).and_return('disk-cid')
        disk_creator.create('persistent-name', 1234, cloud_properties)
      end

      it 'creates database record' do
        expect(cloud).to receive(:create_disk).with(1234, cloud_properties, vm_cid).and_return('disk-cid')

        disk_creator.create('persistent-name', 1234, cloud_properties)

        expect(Bosh::Director::Models::PersistentDisk.count).to eq(1)

        disk_model = Bosh::Director::Models::PersistentDisk.first
        expect(disk_model.disk_cid).to eq('disk-cid')
        expect(disk_model.name).to eq('persistent-name')
        expect(disk_model.active).to eq(false)
        expect(disk_model.instance_id).to eq(1)
        expect(disk_model.size).to eq(1234)
        expect(disk_model.cloud_properties).to eq(cloud_properties)
      end
    end

    describe '#attach' do
      it 'attaches disk' do
        expect(cloud).to receive(:attach_disk).with(vm_cid, 1234).and_return('disk-cid')
        disk_creator.attach(1234)
      end
    end
  end
end
