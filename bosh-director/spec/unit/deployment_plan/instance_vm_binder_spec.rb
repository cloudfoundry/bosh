require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::InstanceVmBinder do
    subject { described_class.new(event_log) }
    let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }

    before { allow(event_log).to receive(:track).and_yield }

    describe '#bind_instance_vm' do
      let(:instance) do
        instance_double('Bosh::Director::DeploymentPlan::Instance', {
          job: job,
          idle_vm: idle_vm,
          index: 'fake-index',
          :current_state= => nil,
          model: instance_model,
        })
      end

      let(:job) do
        instance_double('Bosh::Director::DeploymentPlan::Job', {
          name: 'fake-job-name',
          spec: 'fake-job-spec',
          release: release,
        })
      end

      let(:release) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', spec: 'fake-release-spec') }

      let(:instance_model) { Models::Instance.make(vm: nil) }

      let(:idle_vm) do
        instance_double('Bosh::Director::DeploymentPlan::IdleVm', {
          current_state: { 'fake-vm-existing-state' => true },
          vm: idle_vm_model,
        })
      end

      let(:idle_vm_model) { Models::Vm.make(agent_id: 'fake-agent-id') }

      before { AgentClient.stub(with_defaults: agent) }
      let(:agent) { instance_double('Bosh::Director::AgentClient') }

      it 'sends apply message to an agent' do
        AgentClient.should_receive(:with_defaults).with('fake-agent-id').and_return(agent)
        expect(agent).to receive(:apply).with(be_an_instance_of(Hash))
        subject.bind_instance_vm(instance)
      end

      it 'sends apply message that includes existing vm state' do
        expect(agent).to receive(:apply).with(hash_including('fake-vm-existing-state' => true))
        subject.bind_instance_vm(instance)
      end

      it 'sends apply message to an agent that includes new job spec, instance index, and release spec' do
        expect(agent).to receive(:apply).with(hash_including(
          'job' => 'fake-job-spec',
          'index' => 'fake-index',
        ))
        subject.bind_instance_vm(instance)
      end

      def self.it_rolls_back_instance_and_vm_state(error)
        it 'does not point instance to the vm so that during the next deploy instance can be re-associated with new vm' do
          expect {
            expect { subject.bind_instance_vm(instance) }.to raise_error(error)
          }.to_not change { instance_model.refresh.vm }.from(nil)
        end

        it 'does not change apply spec on vm model' do
          expect {
            expect { subject.bind_instance_vm(instance) }.to raise_error(error)
          }.to_not change { idle_vm_model.refresh.apply_spec }.from(nil)
        end

        it 'does not change current state on the instance' do
          instance.should_not_receive(:current_state=)
          expect { subject.bind_instance_vm(instance) }.to raise_error(error)
        end
      end

      context 'when agent apply succeeds' do
        before { agent.stub(apply: nil) }

        context 'when saving state changes to the database succeeds' do
          it 'the instance points to the vm' do
            expect {
              subject.bind_instance_vm(instance)
            }.to change { instance_model.refresh.vm }.from(nil).to(idle_vm_model)
          end

          it 'the vm apply spec is set to new state' do
            expect {
              subject.bind_instance_vm(instance)
            }.to change { idle_vm_model.refresh.apply_spec }.from(nil).to(hash_including(
              'fake-vm-existing-state' => true,
              'job' => 'fake-job-spec',
            ))
          end

          it 'the instance current state is set to new state' do
            instance.should_receive(:current_state=).with(hash_including(
              'fake-vm-existing-state' => true,
              'job' => 'fake-job-spec',
            ))
            subject.bind_instance_vm(instance)
          end
        end

        context 'when update vm instance in the database fails' do
          error = Exception.new('error')
          before { instance_model.stub(:_update_without_checking).and_raise(error) }
          it_rolls_back_instance_and_vm_state(error)
        end

        context 'when update vm apply spec in the database fails' do
          error = Exception.new('error')
          before { idle_vm_model.stub(:_update_without_checking).and_raise(error) }
          it_rolls_back_instance_and_vm_state(error)
        end
      end

      context 'when agent apply fails' do
        error = RpcTimeout.new('error')
        before { agent.stub(:apply).and_raise(error) }
        it_rolls_back_instance_and_vm_state(error)
      end
    end
  end
end
