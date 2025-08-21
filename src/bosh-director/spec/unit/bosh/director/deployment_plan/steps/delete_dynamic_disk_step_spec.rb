require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe DeleteDynamicDiskStep do
        subject(:step) { DeleteDynamicDiskStep.new(disk) }

        let!(:disk) { FactoryBot.create(:models_dynamic_disk, name: 'disk-name') }
        let(:cloud_factory) { instance_double(CloudFactory) }
        let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
        let(:report) { Stages::Report.new }

        before do
          allow(CloudFactory).to receive(:create).and_return(cloud_factory)
          allow(cloud_factory).to receive(:get).with(disk&.cpi).once.and_return(cloud)
          allow(cloud).to receive(:delete_disk)
          allow(cloud).to receive(:has_disk).and_return(true)
        end

        it 'calls out to cpi associated with disk to delete disk' do
          expect(cloud_factory).to receive(:get).with(disk&.cpi).once.and_return(cloud)
          expect(cloud).to receive(:delete_disk).with(disk.disk_cid)

          step.perform(report)
        end

        it 'deletes dynamic disk from the database' do
          step.perform(report)

          expect(Models::DynamicDisk.find(disk_cid: disk.disk_cid)).to be_nil
        end

        context 'when disk does not exist' do
          before do
            allow(cloud).to receive(:has_disk).and_return(false)
          end

          it 'does not perform any cloud actions' do
            expect(cloud).to_not receive(:delete_disk)

            step.perform(report)

            expect(Models::DynamicDisk.find(disk_cid: disk.disk_cid)).to be_nil
          end
        end

        it 'logs notification of deleting' do
          expect(per_spec_logger).to receive(:info).with("Deleting dynamic disk '#{disk.disk_cid}'")

          step.perform(report)
        end

        context 'when given nil disk' do
          let(:disk) { nil }

          it 'does not perform any cloud actions' do
            expect(cloud).to_not receive(:delete_disk)

            step.perform(report)
          end
        end
      end
    end
  end
end
