require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe UnmountDiskStep do
        subject(:step) { UnmountDiskStep.new(disk) }

        let(:instance) { FactoryBot.create(:models_instance) }
        let(:vm) { FactoryBot.create(:models_vm, instance: instance, active: true) }
        let!(:disk) { FactoryBot.create(:models_persistent_disk, instance: instance, name: '') }
        let(:agent_client) do
          instance_double(AgentClient, list_disk: [disk&.disk_cid], unmount_disk: nil)
        end
        let(:report) { Stages::Report.new }

        before do
          allow(AgentClient).to receive(:with_agent_id).with(vm.agent_id, vm.instance.name).and_return(agent_client)
        end

        describe '#perform' do
          it 'sends unmount_disk method to agent' do
            expect(agent_client).to receive(:unmount_disk).with(disk.disk_cid)

            step.perform(report)
          end

          it 'logs that the disk is being unmounted' do
            expect(per_spec_logger).to receive(:info).with(
              "Unmounting disk '#{disk.disk_cid}' for instance '#{instance}'",
            )

            step.perform(report)
          end

          context 'when agent does not list given disk' do
            before do
              allow(agent_client).to receive(:list_disk).and_return([])
            end

            it 'does not attempt to unmount' do
              expect(agent_client).not_to receive(:unmount_disk)

              step.perform(report)
            end
          end

          context 'when given nil disk' do
            let(:disk) { nil }

            it 'does not communicate with agent' do
              expect(agent_client).not_to receive(:unmount_disk)

              step.perform(report)
            end
          end
        end
      end
    end
  end
end
