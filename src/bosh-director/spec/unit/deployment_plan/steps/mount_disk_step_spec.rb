require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe MountDiskStep do
        subject(:step) { MountDiskStep.new(disk) }

        let(:instance) { Models::Instance.make }
        let(:vm) { Models::Vm.make(instance: instance, active: true) }
        let!(:disk) { Models::PersistentDisk.make(instance: instance, name: '') }
        let(:agent_client) do
          instance_double(AgentClient, list_disk: [disk&.disk_cid], mount_disk: nil)
        end

        before do
          allow(AgentClient).to receive(:with_agent_id).with(vm.agent_id).and_return(agent_client)
        end

        describe '#perform' do
          it 'sends mount_disk method to agent' do
            expect(agent_client).to receive(:wait_until_ready)
            expect(agent_client).to receive(:mount_disk).with(disk.disk_cid)

            step.perform
          end

          it 'logs that the disk is being mounted' do
            expect(agent_client).to receive(:wait_until_ready)
            expect(logger).to receive(:info).with(
              "Mounting disk '#{disk.disk_cid}' for instance '#{instance}'",
            )

            step.perform
          end

          context 'when given nil disk' do
            let(:disk) { nil }

            it 'does not communicate with agent' do
              expect(agent_client).not_to receive(:mount_disk)

              step.perform
            end
          end
        end
      end
    end
  end
end
