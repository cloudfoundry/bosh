require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe UnmountDisksStep do
        subject(:step) { UnmountDisksStep.new(instance_plan) }

        let(:instance) { Models::Instance.make }
        let!(:vm) { Models::Vm.make(instance: instance, active: true) }
        let!(:disk1) { Models::PersistentDisk.make(instance: instance, name: '') }
        let!(:disk2) { Models::PersistentDisk.make(instance: instance, name: 'unmanaged') }
        let(:deployment_instance) { instance_double(Instance, model: instance) }
        let(:instance_plan) { instance_double(InstancePlan, instance: deployment_instance) }
        let(:agent_client) { instance_double(AgentClient, list_disk: [disk1.disk_cid, disk2.disk_cid]) }

        before do
          allow(AgentClient).to receive(:with_agent_id).with(vm.agent_id).and_return(agent_client)
        end

        describe '#perform' do
          it 'unmounts managed, active persistent disk from instance model associated with instance plan' do
            expect(agent_client).to receive(:unmount_disk).with(disk1.disk_cid)

            step.perform
          end
        end
      end
    end
  end
end
