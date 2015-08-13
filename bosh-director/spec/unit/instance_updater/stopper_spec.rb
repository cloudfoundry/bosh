require 'spec_helper'
require 'bosh/director/instance_updater/stopper'

module Bosh::Director
  describe InstanceUpdater::Stopper do
    subject(:stopper) { described_class.new(instance, agent_client, target_state, skip_drain, config, logger) }

    let(:instance) do
      instance_double('Bosh::Director::DeploymentPlan::Instance', {
        spec: 'fake-spec',
        resource_pool_changed?: false,
        persistent_disk_changed?: false,
        networks_changed?: false,
      })
    end

    let(:agent_client) { instance_double('Bosh::Director::AgentClient') }
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
      context 'when the resource pool has changed' do
        before { allow(instance).to receive(:resource_pool_changed?).and_return(true) }
        its(:shutting_down?) { should be(true) }
      end

      context 'when the persistent disks have changed' do
        before { allow(instance).to receive(:persistent_disk_changed?).and_return(true) }
        its(:shutting_down?) { should be(true) }
      end

      context 'when the networks have changed' do
        before { allow(instance).to receive(:networks_changed?).and_return(true) }
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
