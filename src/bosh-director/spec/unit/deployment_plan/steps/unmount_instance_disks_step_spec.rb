require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe UnmountInstanceDisksStep do
        subject(:step) { UnmountInstanceDisksStep.new(instance) }

        let(:instance) { FactoryBot.create(:models_instance) }
        let!(:vm) { FactoryBot.create(:models_vm, instance: instance, active: true) }
        let(:disk1) { Models::PersistentDisk.make(instance: instance, name: '') }
        let(:disk2) { Models::PersistentDisk.make(instance: instance, name: 'unmanaged') }
        let(:unmount_disk1) { instance_double(UnmountDiskStep) }
        let(:unmount_disk2) { instance_double(UnmountDiskStep) }
        let(:report) { Stages::Report.new }

        before do
          allow(UnmountDiskStep).to receive(:new).with(disk1).and_return(unmount_disk1)
          allow(UnmountDiskStep).to receive(:new).with(disk2).and_return(unmount_disk2)
        end

        describe '#perform' do
          it 'unmounts managed, active persistent disk from instance model associated with instance plan' do
            expect(unmount_disk1).to receive(:perform).with(report).once
            expect(unmount_disk2).not_to receive(:perform).with(report)

            step.perform(report)
          end
        end
      end
    end
  end
end
