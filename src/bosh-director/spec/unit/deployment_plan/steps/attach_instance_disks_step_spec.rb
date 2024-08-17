require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe AttachInstanceDisksStep do
        subject(:step) { AttachInstanceDisksStep.new(instance, tags) }

        let(:instance) { FactoryBot.create(:models_instance) }
        let!(:vm) { FactoryBot.create(:models_vm, instance: instance, active: true, cpi: 'vm-cpi') }
        let!(:disk1) { Models::PersistentDisk.make(instance: instance, name: '') }
        let!(:disk2) { Models::PersistentDisk.make(instance: instance, name: 'unmanaged') }
        let(:tags) do
          { 'mytag' => 'myvalue' }
        end
        let(:report) { Stages::Report.new }
        let(:attach_disk_1) { instance_double(AttachDiskStep) }
        let(:attach_disk_2) { instance_double(AttachDiskStep) }

        before do
          allow(AttachDiskStep).to receive(:new).with(disk1, tags).and_return(attach_disk_1)
          allow(AttachDiskStep).to receive(:new).with(disk2, tags).and_return(attach_disk_2)

          allow(attach_disk_1).to receive(:perform).with(report).once
          allow(attach_disk_2).to receive(:perform).with(report).once
        end

        it 'calls out to vms cpi to attach all attached disks' do
          expect(AttachDiskStep).to receive(:new).with(disk1, tags)
          expect(AttachDiskStep).to receive(:new).with(disk2, tags)
          expect(attach_disk_1).to receive(:perform).with(report).once
          expect(attach_disk_2).to receive(:perform).with(report).once

          step.perform(report)
        end

        context 'when the instance does not have an active vm' do
          before do
            vm.update(active: false)
          end

          it 'does nothing' do
            expect(AttachDiskStep).not_to receive(:new)
            expect(AttachDiskStep).not_to receive(:new)
            expect(attach_disk_1).not_to receive(:perform)
            expect(attach_disk_2).not_to receive(:perform)

            step.perform(report)
          end
        end
      end
    end
  end
end
