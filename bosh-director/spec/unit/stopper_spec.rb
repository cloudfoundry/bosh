require 'spec_helper'
require 'bosh/director/stopper'

module Bosh::Director
  describe Stopper do
    subject(:stopper) { described_class.new(instance_plan, target_state, skip_drain, config, logger) }

    let(:instance) do
      instance_double('Bosh::Director::DeploymentPlan::Instance', {
        apply_spec: 'fake-spec',
        vm_type_changed?: false,
        stemcell_changed?: false,
        model: instance_model
      })
    end
    let(:instance_plan) { instance_double('Bosh::Director::DeploymentPlan::InstancePlan',
      instance: instance,
      networks_changed?: false,
      needs_recreate?: false,
      env_changed?: false,
      recreate_deployment?: false,
      persistent_disk_changed?: false
    )
    }
    let(:instance_model) { Models::Instance.make }

    let(:agent_client) { instance_double('Bosh::Director::AgentClient') }
    before { allow(AgentClient).to receive(:with_vm).with(instance.model.vm).and_return(agent_client) }
    let(:target_state) { 'fake-target-state' }
    let(:config) { Config }
    let(:skip_drain) { false }

    describe '#stop' do
      context 'when skip_drain is set to true' do
        let(:skip_drain) { true }

        it 'does not drain' do
          expect(agent_client).to_not receive(:drain)
          expect(stopper).to_not receive(:sleep)
          expect(agent_client).to receive(:stop).with(no_args).ordered
          stopper.stop
        end
      end

      context 'when it is compilation instance' do
        before { instance_model.compilation = true }

        it 'does not drain and stop' do
          expect(agent_client).to_not receive(:drain)
          expect(stopper).to_not receive(:sleep)
          expect(agent_client).to_not receive(:stop)
          stopper.stop
        end
      end

      context 'when it instance does not have vm' do
        before { instance_model.vm = nil }

        it 'does not drain and stop' do
          expect(agent_client).to_not receive(:drain)
          expect(stopper).to_not receive(:sleep)
          expect(agent_client).to_not receive(:stop)
          stopper.stop
        end
      end

      context 'when shutting down' do
        before { allow(subject).to receive_messages(shutting_down?: true) }

        context 'with static drain' do
          it 'sends shutdown with next apply spec and then stops services' do
            expect(agent_client).to receive(:drain).with('shutdown', 'fake-spec').and_return(1).ordered
            expect(subject).to receive(:sleep).with(1).ordered
            expect(agent_client).to receive(:stop).with(no_args).ordered
            subject.stop
          end
        end

        context 'with dynamic drain' do
          it 'sends shutdown with next apply spec and then stops services' do
            expect(agent_client).to receive(:drain).with('shutdown', 'fake-spec').and_return(-2).ordered
            expect(subject).to receive(:wait_for_dynamic_drain).with(-2).ordered
            expect(agent_client).to receive(:stop).with(no_args).ordered
            subject.stop
          end
        end
      end

      context 'when updating' do
        before { allow(subject).to receive_messages(shutting_down?: false) }

        context 'with static drain' do
          it 'sends update with next apply spec and then stops services' do
            expect(agent_client).to receive(:drain).with('update', 'fake-spec').and_return(1).ordered
            expect(subject).to receive(:sleep).with(1).ordered
            expect(agent_client).to receive(:stop).with(no_args).ordered
            subject.stop
          end
        end

        context 'with dynamic drain' do
          it 'sends update with next apply spec and then stops services' do
            expect(agent_client).to receive(:drain).with('update', 'fake-spec').and_return(-2).ordered
            expect(subject).to receive(:wait_for_dynamic_drain).with(-2).ordered
            expect(agent_client).to receive(:stop).with(no_args).ordered
            subject.stop
          end
        end
      end
    end

    describe '#wait_for_dynamic_drain' do
      before { allow(subject).to receive(:sleep) }

      it 'can be canceled' do
        expect(Config).to receive(:task_checkpoint).and_raise(TaskCancelled)
        expect {
          subject.send(:wait_for_dynamic_drain, -1)
        }.to raise_error TaskCancelled
      end

      it 'should wait until the agent says it is done draining' do
        allow(agent_client).to receive(:drain).with("status").and_return(-2, 0)
        expect(subject).to receive(:sleep).with(1).ordered
        expect(subject).to receive(:sleep).with(2).ordered
        subject.send(:wait_for_dynamic_drain, -1)
      end

      it 'should wait until the agent says it is done draining' do
        allow(agent_client).to receive(:drain).with("status").and_return(-2, 3)
        expect(subject).to receive(:sleep).with(1).ordered
        expect(subject).to receive(:sleep).with(2).ordered
        expect(subject).to receive(:sleep).with(3).ordered
        subject.send(:wait_for_dynamic_drain, -1)
      end
    end

    describe '#shutting_down?' do
    
      context 'when recreate deployment is set' do
        before { allow(instance_plan).to receive(:recreate_deployment?).and_return(true) }
        its(:shutting_down?) { should be(true) }
      end

      context 'when the vm type has changed' do
        before { allow(instance).to receive(:vm_type_changed?).and_return(true) }
        its(:shutting_down?) { should be(true) }
      end

      context 'when the stemcell type has changed' do
        before { allow(instance).to receive(:stemcell_changed?).and_return(true) }
        its(:shutting_down?) { should be(true) }
      end

      context 'when the env has changed' do
        before { allow(instance_plan).to receive(:env_changed?).and_return(true) }
        its(:shutting_down?) { should be(true) }
      end

      context 'when the persistent disks have changed' do
        before { allow(instance_plan).to receive(:persistent_disk_changed?).and_return(true) }
        its(:shutting_down?) { should be(true) }
      end

      context 'when the networks have changed' do
        before { allow(instance_plan).to receive(:networks_changed?).and_return(true) }
        its(:shutting_down?) { should be(true) }
      end

      context 'when the target state is detached' do
        let(:target_state) { 'detached' }
        its(:shutting_down?) { should be(true) }
      end

      context 'when the target state is stopped' do
        let(:target_state) { 'stopped' }
        its(:shutting_down?) { should be(true) }
      end

      context 'when the target state is started' do
        let(:target_state) { 'started' }
        its(:shutting_down?) { should be(false) }
      end
    end
  end
end
