require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe DetachDynamicDiskStep do
        subject(:step) { DetachDynamicDiskStep.new(disk) }

        let!(:vm) { FactoryBot.create(:models_vm, stemcell_api_version: 25) }
        let!(:disk) { FactoryBot.create(:models_dynamic_disk, vm: vm, name: 'disk-name') }
        let(:cloud_factory) { instance_double(CloudFactory) }
        let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
        let(:report) { Stages::Report.new }

        before do
          allow(CloudFactory).to receive(:create).and_return(cloud_factory)
          allow(cloud_factory).to receive(:get).with(disk&.cpi, 25).once.and_return(cloud)
          allow(cloud).to receive(:detach_disk)
        end

        it 'calls out to cpi associated with disk to detach disk' do
          expect(cloud_factory).to receive(:get).with(disk&.cpi, 25).once.and_return(cloud)
          expect(cloud).to receive(:detach_disk).with(vm.cid, disk.disk_cid)

          step.perform(report)
        end

        it 'clears vm_cid from disk' do
          step.perform(report)
          expect(Models::DynamicDisk.find(disk_cid: disk.disk_cid).vm_id).to be_nil
        end

        it 'logs notification of detaching' do
          expect(per_spec_logger).to receive(:info).with("Detaching dynamic disk #{disk.disk_cid}")

          step.perform(report)
        end

        context 'when the CPI reports that a disk is not attached' do
          before do
            allow(cloud).to receive( :detach_disk)
                              .with(vm.cid, disk.disk_cid)
                              .and_raise(Bosh::Clouds::DiskNotAttached.new('foo'))
          end

          it 'raises a CloudDiskNotAttached error' do
            expect {
              step.perform(report)
            }.to raise_error(
                   CloudDiskNotAttached,
                   "'#{vm.cid}' VM should have dynamic disk '#{disk.disk_cid}' attached " \
                     "but it doesn't (according to CPI)",
                 )
          end
        end

        context 'when given nil disk' do
          let(:disk) { nil }

          it 'does not perform any cloud actions' do
            expect(cloud).to_not receive(:detach_disk)

            step.perform(report)
          end
        end
      end
    end
  end
end
