require 'spec_helper'
require 'bosh/director/stopper'

module Bosh::Director
  describe Stopper do
    subject(:stopper) { described_class.new(instance_plan, target_state, skip_drain, config, logger) }
    let(:instance_model) { Models::Instance.make(vm: vm) }
    let(:vm) { Models::Vm.make(apply_spec: spec, env: {'old' => 'env'}) }

    let(:agent_client) { instance_double('Bosh::Director::AgentClient') }
    before { allow(AgentClient).to receive(:with_vm).with(instance_model.vm).and_return(agent_client) }
    let(:target_state) { 'fake-target-state' }
    let(:config) { Config }
    let(:skip_drain) { false }


    shared_examples_for 'stopper' do
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
              expect(agent_client).to receive(:drain).with('shutdown', spec).and_return(1).ordered
              expect(subject).to receive(:sleep).with(1).ordered
              expect(agent_client).to receive(:stop).with(no_args).ordered
              subject.stop
            end
          end

          context 'with dynamic drain' do
            it 'sends shutdown with next apply spec and then stops services' do
              expect(agent_client).to receive(:drain).with('shutdown', spec).and_return(-2).ordered
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
              expect(agent_client).to receive(:drain).with('update', spec).and_return(1).ordered
              expect(subject).to receive(:sleep).with(1).ordered
              expect(agent_client).to receive(:stop).with(no_args).ordered
              subject.stop
            end
          end

          context 'with dynamic drain' do
            it 'sends update with next apply spec and then stops services' do
              expect(agent_client).to receive(:drain).with('update', spec).and_return(-2).ordered
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
        let(:desired_instance) { DeploymentPlan::DesiredInstance.new }
        let(:deployment) { instance_double(DeploymentPlan::Planner, recreate: false) }
        let(:job) { instance_double(DeploymentPlan::Job,
          name: 'fake-job',
          deployment: deployment,
          persistent_disk_type: DeploymentPlan::DiskType.new('1'),
          vm_type: DeploymentPlan::VmType.new(new_vm_type),
          stemcell: DeploymentPlan::Stemcell.new(new_stemcell),
          env: DeploymentPlan::Env.new(new_env)
        ) }
        let(:new_stemcell) { {'name' => 'stemcell-name', 'version' => '2.0.6'} }
        let(:new_env) { {'old' => 'env'} }
        let(:new_vm_type) { {'name' => 'vm-type-name', 'cloud_properties' => {}} }
        let(:az) { DeploymentPlan::AvailabilityZone.new('az-1', {}) }
        let(:instance) do
          instance = DeploymentPlan::Instance.new(job, 1, 'started', deployment, {}, az, false, logger)
          instance.bind_existing_instance_model(instance_model)
          instance
        end
        let(:instance_plan) { DeploymentPlan::InstancePlan.new(existing_instance: instance_model, instance: instance, desired_instance: desired_instance) }

        describe '#shutting_down?' do
          context 'when recreate deployment is set' do
            let(:deployment) { instance_double(DeploymentPlan::Planner, recreate: true) }

            its(:shutting_down?) { should be(true) }
          end

          context 'when the vm type has changed' do
            let(:new_vm_type) { {'name' => 'new-vm-type', 'cloud_properties' => {'new' => 'properties'}} }

            its(:shutting_down?) { should be(true) }
          end

          context 'when the stemcell type has changed' do
            let(:new_stemcell) { {'name' => 'new-stemcell-name', 'version' => '2.0.7'} }
            its(:shutting_down?) { should be(true) }
          end

          context 'when the env has changed' do
            let(:new_env) { {'new' => 'env'} }
            its(:shutting_down?) { should be(true) }
          end

          context 'when the persistent disks have changed' do
            before do
              instance_plan.existing_instance.add_persistent_disk(Models::PersistentDisk.make)
            end
            its(:shutting_down?) { should be(true) }
          end

          context 'when the networks have changed' do
            before do
              network = DeploymentPlan::DynamicNetwork.new('name', [], logger)
              reservation = DesiredNetworkReservation.new_dynamic(instance, network)
              instance_plan.network_plans = [DeploymentPlan::NetworkPlan.new(reservation: reservation)]
            end

            its(:shutting_down?) { should be(true) }
          end

          context 'when the instance is being recreated' do
            let(:deployment) { instance_double(DeploymentPlan::Planner, recreate: true) }

            its(:shutting_down?) { should be(true) }
          end

          context 'target state' do
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
              its(:shutting_down?) { should be(shutting_down_based_on_target_state) }
            end
          end
        end
      end
    end

    context 'when trying to stop obsolete instances' do
      let(:instance_plan) { DeploymentPlan::InstancePlan.new(existing_instance: instance_model, instance: nil, desired_instance: nil) }
      let(:spec) { {} }
      let(:shutting_down_based_on_target_state) { true }

      it_behaves_like 'stopper'
    end

    context 'when trying to stop instances' do
      let(:instance) { instance_double(DeploymentPlan::Instance, model: instance_model, apply_spec: spec) }
      let(:desired_instance) { DeploymentPlan::DesiredInstance.new }
      let(:instance_plan) { DeploymentPlan::InstancePlan.new(existing_instance: instance_model, instance: instance, desired_instance: desired_instance) }
      let(:spec) do
        {
          'vm_type' => {
            'name' => 'vm-type-name',
            'cloud_properties' => {}
          },
          'stemcell' => {
            'name' => 'stemcell-name',
            'version' => '2.0.6'
          }
        }
      end
      let(:shutting_down_based_on_target_state) { false }

      it_behaves_like 'stopper'
    end
  end
end
