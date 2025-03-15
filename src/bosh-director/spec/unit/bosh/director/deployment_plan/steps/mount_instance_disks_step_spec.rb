require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe MountInstanceDisksStep do
        subject(:step) { MountInstanceDisksStep.new(instance) }

        let(:instance) { FactoryBot.create(:models_instance) }
        let!(:managed_disk) { FactoryBot.create(:models_persistent_disk, instance: instance, name: '') }
        let!(:unmanaged_disk) { FactoryBot.create(:models_persistent_disk, instance: instance, name: 'disk-name-me') }
        let(:mount_disk_step) { instance_double(MountDiskStep) }
        let(:report) { Stages::Report.new }

        it 'mounts managed disks but does not mount unmanaged disks' do
          expect(MountDiskStep).to receive(:new).with(managed_disk).and_return(mount_disk_step)
          expect(mount_disk_step).to receive(:perform).with(report)

          step.perform(report)
        end
      end
    end
  end
end
