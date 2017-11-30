require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe PrepareInstanceStep do
        subject(:step) { PrepareInstanceStep.new(instance_plan, use_active_vm: use_active_vm) }

        let(:instance) { Models::Instance.make }
        let(:deployment_instance) { instance_double(Instance, model: instance) }
        let(:instance_plan) { instance_double(InstancePlan, instance: deployment_instance) }
        let(:spec) { instance_double(InstanceSpec, as_apply_spec: 'apply-me', as_jobless_apply_spec: 'unemployed') }

        before do
          allow(InstanceSpec).to receive(:create_from_instance_plan).with(instance_plan).and_return spec
        end

        describe '#perform' do
          context 'with an instance plan referring to an instance with both new and old vms' do
            let(:active_agent)  { instance_double(AgentClient) }
            let(:lazy_agent)  { instance_double(AgentClient) }

            before do
              Models::Vm.make(instance: instance, agent_id: 'active-agent', active: true)
              Models::Vm.make(instance: instance, agent_id: 'lazy-agent', active: false)
              allow(AgentClient).to receive(:with_agent_id).with('active-agent').and_return(active_agent)
              allow(AgentClient).to receive(:with_agent_id).with('lazy-agent').and_return(lazy_agent)
            end

            context 'when preparing the active vm' do
              let(:use_active_vm) { true }

              it 'sends the full spec to the active vms agent' do
                expect(active_agent).to receive(:prepare).with('apply-me')

                step.perform
              end
            end

            context 'when preparing the inactive vm' do
              let(:use_active_vm) { false }

              it 'sends the jobless spec to the other vms agent' do
                expect(lazy_agent).to receive(:prepare).with('unemployed')

                step.perform
              end
            end
          end

          context 'with an instance plan with only an old vm' do
            let(:old_agent) { instance_double(AgentClient) }

            before do
              Models::Vm.make(instance: instance, agent_id: 'old-agent', active: true)
              allow(AgentClient).to receive(:with_agent_id).with('old-agent').and_return(old_agent)
            end

            context 'when preparing the active vm' do
              let(:use_active_vm) { true }

              it 'sends the full spec to the active vms agent' do
                expect(old_agent).to receive(:prepare).with('apply-me')

                step.perform
              end
            end

            context 'when preparing the inactive vm' do
              let(:use_active_vm) { false }

              it 'raises error' do
                expect { step.perform }.to raise_error('no inactive VM available to prepare for instance')
              end
            end
          end

          context 'with an instance plan with only a new vm' do
            let(:new_agent) { instance_double(AgentClient) }

            before do
              Models::Vm.make(instance: instance, agent_id: 'new-agent', active: false)
              allow(AgentClient).to receive(:with_agent_id).with('new-agent').and_return(new_agent)
            end

            context 'when preparing the active vm' do
              let(:use_active_vm) { true }

              it 'raises error' do
                expect { step.perform }.to raise_error('no active VM available to prepare for instance')
              end
            end

            context 'when preparing the inactive vm' do
              let(:use_active_vm) { false }

              it 'sends the jobless spec to the other vms agent' do
                expect(new_agent).to receive(:prepare).with('unemployed')

                step.perform
              end
            end
          end
        end
      end
    end
  end
end
