require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe VmSpecApplier do
      subject(:spec_applier) {VmSpecApplier.new}

      describe '#apply_initial_vm_state' do
        let(:agent_client) {instance_double(AgentClient)}
        let(:spec) {instance_double(InstanceSpec)}

        before do
          allow(AgentClient).to receive(:with_agent_id).with('my-agent').and_return(agent_client)
          allow(spec).to receive(:as_apply_spec).and_return({
            'networks' => 'my-networks',
            'deployment' => 'my-deployment',
            'job' => 'my-job',
            'index' => 'my-index',
            'id' => 'my-id',
            'and' => 'other_keys',
          })
          allow(spec).to receive(:full_spec).and_return({
            'networks' => 'my-networks',
            'deployment' => 'my-deployment',
            'job' => 'my-job',
            'index' => 'my-index',
            'id' => 'my-id',
            'and' => 'other_keys',
            'as' => 'well',
            'stemcell' => 'my-stemcell',
            'vm_type' => 'my-type',
            'env' => 'my-env',
          })
          allow(agent_client).to receive(:get_state).and_return({
            'networks' => 'agent-network'
          })
        end

        it 'applies limited fields from given spec to correct agent' do
          expect(agent_client).to receive(:apply).with({
            'networks' => 'my-networks',
            'deployment' => 'my-deployment',
            'job' => 'my-job',
            'index' => 'my-index',
            'id' => 'my-id',
          })

          expect(spec_applier.apply_initial_vm_state(spec, 'my-agent')).to eq({
            'networks' => 'agent-network',
            'deployment' => 'my-deployment',
            'job' => 'my-job',
            'index' => 'my-index',
            'id' => 'my-id',
            'stemcell' => 'my-stemcell',
            'vm_type' => 'my-type',
            'env' => 'my-env',
          })
        end
      end
    end
  end
end
