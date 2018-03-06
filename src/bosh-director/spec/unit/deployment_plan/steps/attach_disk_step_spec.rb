require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe AttachDiskStep do
        subject(:step) { AttachDiskStep.new(disk, tags) }

        let!(:vm) { Models::Vm.make(active: true, instance: instance, stemcell_api_version: 25) }
        let(:instance) { Models::Instance.make }
        let!(:disk) { Models::PersistentDisk.make(instance: instance, name: '') }
        let(:cloud_factory) { instance_double(CloudFactory) }
        let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
        let(:metadata_updater_cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
        let(:tags) { { 'mytag' => 'myvalue' } }
        let(:meta_updater) { instance_double(MetadataUpdater, update_disk_metadata: nil) }
        let(:report) { Stages::Report.new }

        before do
          allow(CloudFactory).to receive(:create).and_return(cloud_factory)
          allow(cloud_factory).to receive(:get).with(disk&.cpi, 25).once.and_return(cloud)
          allow(cloud_factory).to receive(:get).with(disk&.cpi).once.and_return(metadata_updater_cloud)
          allow(cloud).to receive(:attach_disk)
          allow(MetadataUpdater).to receive(:build).and_return(meta_updater)
        end

        it 'calls out to cpi associated with disk to attach disk' do
          expect(cloud).to receive(:attach_disk).with(vm.cid, disk.disk_cid)

          step.perform(report)
        end

        it 'logs notification of attaching' do
          expect(logger).to receive(:info).with("Attaching disk #{disk.disk_cid}")

          step.perform(report)
        end

        it 'updates the disk metadata with given tags' do
          expect(meta_updater).to receive(:update_disk_metadata).with(metadata_updater_cloud, disk, tags)

          step.perform(report)
        end

        context 'when the CPI reports error when a disk is not able to be attached' do
          let(:cpi_error) { Bosh::Clouds::CloudError.new('cloud error') }

          before do
            allow(cloud).to receive(:attach_disk)
              .with(vm.cid, disk.disk_cid)
              .and_raise(cpi_error)
          end

          it 'raises a CloudDiskNotAttached error' do
            expect { step.perform(report) }.to raise_error(cpi_error)
          end
        end

        context 'when given nil disk' do
          let(:disk) { nil }

          it 'does not perform any cloud actions' do
            expect(cloud).to_not receive(:attach_disk)

            step.perform(report)
          end
        end

        context 'when given disk with an instance that has no active vm' do
          let(:step) { AttachDiskStep.new(disk_without_vm, tags) }
          let(:instance_without_vm) { Models::Instance.make }
          let!(:disk_without_vm) { Models::PersistentDisk.make(instance: instance_without_vm, name: 'no vm for me') }

          it 'does not perform any cloud actions' do
            expect(cloud).to_not receive(:attach_disk)

            step.perform(report)
          end
        end
      end
    end
  end
end
