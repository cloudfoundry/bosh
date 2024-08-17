require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe DetachInstanceDisksStep do
        subject(:step) { DetachInstanceDisksStep.new(instance) }

        let(:instance) { FactoryBot.create(:models_instance) }
        let!(:vm) { Models::Vm.make(instance: instance, active: true, cpi: 'vm-cpi') }
        let!(:disk1) { Models::PersistentDisk.make(instance: instance, name: '') }
        let!(:disk2) { Models::PersistentDisk.make(instance: instance, name: 'unmanaged') }

        let(:detach_disk_1) { instance_double(DetachDiskStep) }
        let(:detach_disk_2) { instance_double(DetachDiskStep) }

        let(:report) { Stages::Report.new }

        before do
          allow(DetachDiskStep).to receive(:new).with(disk1).and_return(detach_disk_1)
          allow(DetachDiskStep).to receive(:new).with(disk2).and_return(detach_disk_2)

          allow(detach_disk_1).to receive(:perform).with(report).once
          allow(detach_disk_2).to receive(:perform).with(report).once
        end

        it 'calls out to vms cpi to detach all attached disks' do
          expect(DetachDiskStep).to receive(:new).with(disk1)
          expect(DetachDiskStep).to receive(:new).with(disk2)
          expect(detach_disk_1).to receive(:perform).with(report).once
          expect(detach_disk_2).to receive(:perform).with(report).once

          step.perform(report)
        end

        context 'when the instance does not have an active vm' do
          before do
            vm.update(active: false)
          end

          it 'does nothing' do
            expect(DetachDiskStep).not_to receive(:new)
            expect(DetachDiskStep).not_to receive(:new)
            expect(detach_disk_1).not_to receive(:perform).with(report)
            expect(detach_disk_2).not_to receive(:perform).with(report)

            step.perform(report)
          end
        end
      end
    end
  end
end
