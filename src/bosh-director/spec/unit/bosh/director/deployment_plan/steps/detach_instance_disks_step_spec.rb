require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe DetachInstanceDisksStep do
        subject(:step) { DetachInstanceDisksStep.new(instance) }

        let(:instance) { FactoryBot.create(:models_instance) }
        let!(:vm) { FactoryBot.create(:models_vm, instance: instance, active: true, cpi: 'vm-cpi') }
        let!(:disk1) { FactoryBot.create(:models_persistent_disk, instance: instance, name: '') }
        let!(:disk2) { FactoryBot.create(:models_persistent_disk, instance: instance, name: 'unmanaged') }
        let!(:dynamic_disk_1) { FactoryBot.create(:models_dynamic_disk, vm: vm) }
        let!(:dynamic_disk_2) { FactoryBot.create(:models_dynamic_disk, vm: vm) }

        let(:detach_disk_1) { instance_double(DetachDiskStep) }
        let(:detach_disk_2) { instance_double(DetachDiskStep) }
        let(:detach_dynamic_disk_1) { instance_double(DetachDynamicDiskStep) }
        let(:detach_dynamic_disk_2) { instance_double(DetachDynamicDiskStep) }

        let(:report) { Stages::Report.new }

        before do
          allow(DetachDiskStep).to receive(:new).with(disk1).and_return(detach_disk_1)
          allow(DetachDiskStep).to receive(:new).with(disk2).and_return(detach_disk_2)
          allow(DetachDynamicDiskStep).to receive(:new).with(dynamic_disk_1).and_return(detach_dynamic_disk_1)
          allow(DetachDynamicDiskStep).to receive(:new).with(dynamic_disk_2).and_return(detach_dynamic_disk_2)

          allow(detach_disk_1).to receive(:perform).with(report).once
          allow(detach_disk_2).to receive(:perform).with(report).once
          allow(detach_dynamic_disk_1).to receive(:perform).with(report).once
          allow(detach_dynamic_disk_2).to receive(:perform).with(report).once
        end

        it 'calls out to vms cpi to detach all attached persistent disks' do
          expect(DetachDiskStep).to receive(:new).with(disk1)
          expect(DetachDiskStep).to receive(:new).with(disk2)
          expect(detach_disk_1).to receive(:perform).with(report).once
          expect(detach_disk_2).to receive(:perform).with(report).once

          step.perform(report)
        end

        it 'calls out to vms cpi to detach all attached dynamic disks' do
          expect(DetachDynamicDiskStep).to receive(:new).with(dynamic_disk_1)
          expect(DetachDynamicDiskStep).to receive(:new).with(dynamic_disk_2)
          expect(detach_dynamic_disk_1).to receive(:perform).with(report).once
          expect(detach_dynamic_disk_2).to receive(:perform).with(report).once

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
            expect(DetachDynamicDiskStep).not_to receive(:new)
            expect(DetachDynamicDiskStep).not_to receive(:new)
            expect(detach_dynamic_disk_1).not_to receive(:perform).with(report)
            expect(detach_dynamic_disk_2).not_to receive(:perform).with(report)

            step.perform(report)
          end
        end
      end
    end
  end
end
