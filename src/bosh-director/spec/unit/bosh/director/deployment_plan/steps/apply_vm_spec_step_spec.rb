require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe ApplyVmSpecStep do
        subject(:step) { ApplyVmSpecStep.new(instance_plan) }
        let(:report) do
          rp = Stages::Report.new
          rp.vm = vm
          rp
        end

        describe '#perform' do
          let(:agent_client) { instance_double(AgentClient, apply: nil, get_state: { 'networks' => 'agent-network' }) }
          let(:instance_plan) { instance_double(InstancePlan, spec: spec, instance: plan_instance) }
          let(:plan_instance) { instance_double(Instance, add_state_to_model: nil) }
          let(:spec) { instance_double(InstanceSpec) }
          let(:vm) do
            instance_double(
              Models::Vm,
              :agent_id => 'my-agent',
              :network_spec= => nil,
              :env_json= => nil,
              :cloud_properties_json= => nil,
              :stemcell_name= => nil,
              :stemcell_version= => nil,
            )
          end

          before do
            allow(AgentClient).to receive(:with_agent_id).with('my-agent', 'unknown').and_return(agent_client)
            allow(spec).to receive(:as_apply_spec).and_return(
              'networks' => 'my-networks',
              'deployment' => 'my-deployment',
              'job' => 'my-job',
              'index' => 'my-index',
              'id' => 'my-id',
              'and' => 'other_keys',
            )
            allow(vm).to receive(:save)
            allow(spec).to receive(:full_spec).and_return(
              'networks' => 'my-networks',
              'deployment' => 'my-deployment',
              'job' => 'my-job',
              'index' => 'my-index',
              'id' => 'my-id',
              'and' => 'other_keys',
              'as' => 'well',
              'stemcell' => { 'name' => 'ubuntu', 'version' => '1' },
              'vm_type' => { 'cloud_properties' => { 'a' => 'b' } },
              'update' => update_spec,
              'env' => { 'env' => 'json' },
            )
          end

          let(:update_spec) { double(:update_spec) }

          it 'applies limited fields from given spec to correct agent' do
            expect(agent_client).to receive(:apply).with({
              'networks' => 'my-networks',
              'deployment' => 'my-deployment',
              'job' => 'my-job',
              'index' => 'my-index',
              'id' => 'my-id',
            })

            expect(plan_instance).to receive(:add_state_to_model).with({
              'networks' => 'agent-network',
              'deployment' => 'my-deployment',
              'job' => 'my-job',
              'index' => 'my-index',
              'id' => 'my-id',
              'stemcell' => { 'name' => 'ubuntu', 'version' => '1' },
              'vm_type' => { 'cloud_properties' => { 'a' => 'b' } },
              'update' => update_spec,
              'env' => { 'env' => 'json' },
            })

            step.perform(report)
          end

          it 'sets the network_spec on the vm' do
            expect(vm).to receive(:network_spec=).with('agent-network')

            step.perform(report)
          end

          it 'sets env state on the vm' do
            expect(vm).to receive(:env_json=).with({ 'env' => 'json' }.to_json)

            step.perform(report)
          end

          it 'sets cloud properties on the vm' do
            expect(vm).to receive(:cloud_properties_json=).with({ 'a' => 'b' }.to_json)

            step.perform(report)
          end

          it 'sets stemcell name and version on the vm' do
            expect(vm).to receive(:stemcell_name=).with('ubuntu')
            expect(vm).to receive(:stemcell_version=).with('1')

            step.perform(report)
          end

          context 'when cloud_properties are nil' do
            before do
              allow(spec).to receive(:full_spec).and_return(
                'networks' => 'my-networks',
                'deployment' => 'my-deployment',
                'job' => 'my-job',
                'index' => 'my-index',
                'id' => 'my-id',
                'and' => 'other_keys',
                'as' => 'well',
                'stemcell' => { 'name' => 'ubuntu', 'version' => '1' },
                'vm_type' => {},
                'env' => { 'env' => 'json' },
              )
            end

            it 'should gracefully handle nil cloud_properties when updating the vm model' do
              expect(vm).to receive(:cloud_properties_json=).with({}.to_json)

              step.perform(report)
            end
          end
        end
      end
    end
  end
end
