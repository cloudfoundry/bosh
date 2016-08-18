require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe DiskCreator do
    let(:vm_cid) { 1 }
    let(:cloud) { Bosh::Director::Config.cloud }
    let(:disk_creator) { DiskCreator.new(cloud, vm_cid)}

    describe '#create' do
      it 'creates disk' do
        expect(cloud).to receive(:create_disk).with(1234, {}, vm_cid)
        disk_creator.create(1234, {})
      end
    end

    describe '#attach' do
      it 'attaches disk' do
        expect(cloud).to receive(:attach_disk).with(vm_cid, 1234)
        disk_creator.attach(1234)
      end
    end
  end
end
