require 'spec_helper'
require 'bosh/director/stopper'

module Bosh::Director
  describe Stopper do
    subject(:stopper) { described_class }
    let(:vm_model) { Models::Vm.make(cid: 'vm-cid', instance_id: instance_model.id) }
    let(:instance_model) { Models::Instance.make(spec: spec) }
    let(:agent_client) { instance_double('Bosh::Director::AgentClient') }
    let(:target_state) { 'fake-target-state' }
    let(:options) { {} }
    let(:skip_drain) { false }
    let(:deployment_model) { instance_double(Bosh::Director::Models::Deployment, name: 'fake-deployment') }
    let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }
    let(:current_job_state) { 'running' }
    let(:desired_instance) { DeploymentPlan::DesiredInstance.new(instance_group) }

    let(:instance_group) do
      instance_double(
        DeploymentPlan::InstanceGroup,
        name: 'fake-job-name',
        default_network: {},
      )
    end

    let(:instance) do
      instance_double(
        DeploymentPlan::Instance,
        instance_group_name: instance_group.name,
        model: instance_model,
        availability_zone: DeploymentPlan::AvailabilityZone.new('az', {}),
        index: 0,
        uuid: SecureRandom.uuid,
        rendered_templates_archive: nil,
        configuration_hash: { 'fake-spec' => true },
        template_hashes: [],
        current_job_state: current_job_state,
        deployment_model: deployment_model,
      )
    end

    let(:instance_plan) do
      DeploymentPlan::InstancePlan.new(
        existing_instance: instance_model,
        instance: instance,
        desired_instance: desired_instance,
        skip_drain: skip_drain,
        variables_interpolator: variables_interpolator,
      )
    end

    let(:spec) do
      {
        'vm_type' => {
          'name' => 'vm-type-name',
          'cloud_properties' => {},
        },
        'stemcell' => {
          'name' => 'stemcell-name',
          'version' => '2.0.6',
        },
        'networks' => {},
      }
    end

    let(:drain_spec) do
      {
        'networks' => {},
        'template_hashes' => [],
        'configuration_hash' => { 'fake-spec' => true },
      }
    end

    let(:pre_stop_options) do
      {
        'env' => {
          'BOSH_VM_NEXT_STATE' => 'keep',
          'BOSH_INSTANCE_NEXT_STATE' => 'keep',
          'BOSH_DEPLOYMENT_NEXT_STATE' => 'keep',
        },
      }
    end

    before do
      fake_app
      allow(instance).to receive(:current_networks)
      instance_spec = DeploymentPlan::InstanceSpec.new(spec, instance, variables_interpolator)
      allow(instance_plan).to receive(:spec).and_return(instance_spec)

      instance_model.active_vm = vm_model
      allow(AgentClient).to receive(:with_agent_id).with(instance_model.agent_id, instance_model.name).and_return(agent_client)
    end

    describe '#stop' do
      context 'when skip_drain is set to true' do
        let(:skip_drain) { true }

        it 'does not execute pre-stop' do
          expect(agent_client).to_not receive(:run_script).with('pre-stop', {})
          expect(agent_client).to_not receive(:drain)
          expect(stopper).to_not receive(:sleep)
          expect(agent_client).to receive(:stop).with(no_args).ordered
          expect(agent_client).to receive(:run_script).with('post-stop', {}).ordered
          stopper.stop(instance_plan: instance_plan, target_state: target_state)
        end

        it 'does not drain' do
          expect(agent_client).to_not receive(:drain)
          expect(stopper).to_not receive(:sleep)
          expect(agent_client).to receive(:stop).with(no_args).ordered
          expect(agent_client).to receive(:run_script).with('post-stop', {}).ordered
          stopper.stop(instance_plan: instance_plan, target_state: target_state)
        end
      end

      context 'when it is instance with unresponsive agent' do
        let(:current_job_state) { 'unresponsive' }

        it 'does not drain and stop' do
          expect(agent_client).to_not receive(:run_script).with('pre-stop', {})
          expect(agent_client).to_not receive(:drain)
          expect(stopper).to_not receive(:sleep)
          expect(agent_client).to_not receive(:stop)
          expect(agent_client).to_not receive(:run_script).with('post-stop', {})
          stopper.stop(instance_plan: instance_plan, target_state: target_state)
        end
      end

      context 'when it is compilation instance' do
        before { instance_model.compilation = true }

        it 'does not drain and stop' do
          expect(agent_client).to_not receive(:run_script).with('pre-stop', {})
          expect(agent_client).to_not receive(:drain)
          expect(stopper).to_not receive(:sleep)
          expect(agent_client).to_not receive(:stop)
          expect(agent_client).to_not receive(:run_script).with('post-stop', {})
          stopper.stop(instance_plan: instance_plan, target_state: target_state)
        end
      end

      context 'when the instance does not have vm' do
        before { instance_model.active_vm = nil }

        it 'does not drain and stop' do
          expect(agent_client).to_not receive(:run_script).with('pre-stop', {})
          expect(agent_client).to_not receive(:drain)
          expect(stopper).to_not receive(:sleep)
          expect(agent_client).to_not receive(:stop)
          expect(agent_client).to_not receive(:run_script).with('post-stop', {})
          stopper.stop(instance_plan: instance_plan, target_state: target_state)
        end
      end

      context 'when shutting down' do
        before { allow(subject).to receive_messages(needs_shutdown?: true) }

        context 'with static drain' do
          it 'sends shutdown with next apply spec and then stops services' do
            expect(agent_client).to receive(:run_script).with('pre-stop', pre_stop_options)
            expect(agent_client).to receive(:drain).with('shutdown', drain_spec).and_return(1).ordered
            expect(subject).to receive(:sleep).with(1).ordered
            expect(agent_client).to receive(:stop).with(no_args).ordered
            expect(agent_client).to receive(:run_script).with('post-stop', {}).ordered
            stopper.stop(instance_plan: instance_plan, target_state: target_state)
          end
        end

        context 'with dynamic drain' do
          it 'sends shutdown with next apply spec and then stops services' do
            expect(agent_client).to receive(:run_script).with('pre-stop', pre_stop_options)
            allow(agent_client).to receive(:drain).with('status').and_return(-1, 0)
            expect(agent_client).to receive(:drain).with('shutdown', drain_spec).and_return(-2).ordered
            expect(agent_client).to receive(:stop).with(no_args).ordered
            expect(agent_client).to receive(:run_script).with('post-stop', {}).ordered
            stopper.stop(instance_plan: instance_plan, target_state: target_state)
          end
        end
      end

      context 'when updating' do
        before { allow(subject).to receive_messages(needs_shutdown?: false) }

        context 'with static drain' do
          it 'sends update with next apply spec and then stops services' do
            expect(agent_client).to receive(:run_script).with('pre-stop', pre_stop_options)
            expect(agent_client).to receive(:drain).with('update', drain_spec).and_return(1).ordered
            expect(subject).to receive(:sleep).with(1).ordered
            expect(agent_client).to receive(:stop).with(no_args).ordered
            expect(agent_client).to receive(:run_script).with('post-stop', {}).ordered
            stopper.stop(instance_plan: instance_plan, target_state: target_state)
          end
        end

        context 'with dynamic drain' do
          it 'sends update with next apply spec and then stops services' do
            allow(agent_client).to receive(:drain).with('status').and_return(-1, 0)

            expect(agent_client).to receive(:run_script).with('pre-stop', pre_stop_options).ordered
            expect(agent_client).to receive(:drain).with('update', drain_spec).and_return(-2).ordered
            expect(agent_client).to receive(:stop).with(no_args).ordered

            expect(agent_client).to receive(:run_script).with('post-stop', {}).ordered
            stopper.stop(instance_plan: instance_plan, target_state: target_state)
          end

          it 'waits on the agent' do
            allow(agent_client).to receive(:run_script).with('pre-stop', pre_stop_options)
            allow(agent_client).to receive(:run_script).with('post-stop', {})
            allow(agent_client).to receive(:stop)
            allow(agent_client).to receive(:drain).with('status').and_return(-1, 0)

            expect(agent_client).to receive(:drain).with('update', drain_spec).and_return(-2).ordered
            expect(subject).to receive(:sleep).with(2).ordered
            expect(subject).to receive(:sleep).with(1).ordered
            stopper.stop(instance_plan: instance_plan, target_state: target_state)
          end
        end
      end

      context 'when the instance needs shutting down' do
        before do
          allow(instance_plan).to receive(:needs_shutting_down?).and_return(true)
        end

        it 'drains with shutdown' do
          expect(agent_client).to receive(:run_script).with('pre-stop', pre_stop_options).ordered
          expect(agent_client).to receive(:drain).with('shutdown', drain_spec).and_return(1).ordered
          expect(agent_client).to receive(:stop).ordered
          expect(agent_client).to receive(:run_script).with('post-stop', {}).ordered
          stopper.stop(instance_plan: instance_plan, target_state: target_state)
        end
      end

      context 'when the persistent disks have changed' do
        before do
          allow(instance_plan).to receive(:needs_shutting_down?).and_return(false)
          allow(instance_plan).to receive(:persistent_disk_changed?).and_return(true)
          instance_plan.existing_instance.add_persistent_disk(Models::PersistentDisk.make)
        end

        it 'drains with shutdown' do
          expect(agent_client).to receive(:run_script).with('pre-stop', pre_stop_options).ordered
          expect(agent_client).to receive(:drain).with('shutdown', drain_spec).and_return(1).ordered
          expect(agent_client).to receive(:stop).ordered
          expect(agent_client).to receive(:run_script).with('post-stop', {}).ordered
          stopper.stop(instance_plan: instance_plan, target_state: target_state)
        end
      end

      context 'when "target state" is "detached"' do
        let(:target_state) { 'detached' }

        it 'drains with shutdown' do
          expect(agent_client).to receive(:run_script).with('pre-stop', pre_stop_options).ordered
          expect(agent_client).to receive(:drain).with('shutdown', drain_spec).and_return(1).ordered
          expect(agent_client).to receive(:stop).ordered
          expect(agent_client).to receive(:run_script).with('post-stop', {}).ordered
          stopper.stop(instance_plan: instance_plan, target_state: target_state)
        end
      end

      context 'when "target state" is "stopped"' do
        let(:target_state) { 'stopped' }

        it 'drains with shutdown' do
          expect(agent_client).to receive(:run_script).with('pre-stop', pre_stop_options).ordered
          expect(agent_client).to receive(:drain).with('shutdown', drain_spec).and_return(1).ordered
          expect(agent_client).to receive(:stop).ordered
          expect(agent_client).to receive(:run_script).with('post-stop', {}).ordered
          stopper.stop(instance_plan: instance_plan, target_state: target_state)
        end
      end

      context 'when "target state" is "started"' do
        let(:target_state) { 'started' }

        before do
          allow(instance_plan).to receive(:needs_shutting_down?).and_return(false)
          allow(instance_plan).to receive(:persistent_disk_changed?).and_return(false)
        end

        it 'does not shutdown' do
          expect(agent_client).to receive(:run_script).with('pre-stop', pre_stop_options).ordered
          expect(agent_client).to receive(:drain).with('update', drain_spec).and_return(1).ordered
          expect(agent_client).to receive(:stop).ordered
          expect(agent_client).to receive(:run_script).with('post-stop', {}).ordered
          stopper.stop(instance_plan: instance_plan, target_state: target_state)
        end
      end

      context 'when intent for stopping is given' do
        before do
          allow(subject).to receive_messages(needs_shutdown?: true)
          allow(agent_client).to receive(:run_script)
          allow(agent_client).to receive(:drain).and_return(1)
          allow(agent_client).to receive(:stop)
        end

        context 'when `intent` is `delete_vm`' do
          let(:pre_stop_options) do
            {
              'env' => {
                'BOSH_VM_NEXT_STATE' => 'delete',
                'BOSH_INSTANCE_NEXT_STATE' => 'keep',
                'BOSH_DEPLOYMENT_NEXT_STATE' => 'keep',
              },
            }
          end

          it 'should only set BOSH_VM_NEXT_STATE as delete' do
            stopper.stop(instance_plan: instance_plan, target_state: target_state, intent: :delete_vm)
            expect(agent_client).to have_received(:run_script).with('pre-stop', pre_stop_options)
          end
        end

        context 'when `intent` is `delete_instance`' do
          let(:pre_stop_options) do
            {
              'env' => {
                'BOSH_VM_NEXT_STATE' => 'delete',
                'BOSH_INSTANCE_NEXT_STATE' => 'delete',
                'BOSH_DEPLOYMENT_NEXT_STATE' => 'keep',
              },
            }
          end

          it 'should set BOSH_INSTANCE_NEXT_STATE_DELETE as delete' do
            stopper.stop(instance_plan: instance_plan, target_state: target_state, intent: :delete_instance)
            expect(agent_client).to have_received(:run_script).with('pre-stop', pre_stop_options)
          end
        end

        context ' when `intent` is `delete_deployment`' do
          let(:pre_stop_options) do
            {
              'env' => {
                'BOSH_VM_NEXT_STATE' => 'delete',
                'BOSH_INSTANCE_NEXT_STATE' => 'delete',
                'BOSH_DEPLOYMENT_NEXT_STATE' => 'delete',
              },
            }
          end

          it 'should only set BOSH_DEPLOYMENT_NEXT_STATE_DELETE as delete' do
            stopper.stop(instance_plan: instance_plan, target_state: target_state, intent: :delete_deployment)
            expect(agent_client).to have_received(:run_script).with('pre-stop', pre_stop_options)
          end
        end
      end

      context 'when reason for stop is not given' do
        before do
          allow(subject).to receive_messages(needs_shutdown?: false)
          allow(agent_client).to receive(:run_script)
          allow(agent_client).to receive(:drain).and_return(1)
          allow(agent_client).to receive(:stop)
        end

        it 'should keep all pre-stop env variables as false' do
          stopper.stop(instance_plan: instance_plan, target_state: target_state)
          expect(agent_client).to have_received(:run_script).with('pre-stop', pre_stop_options)
        end
      end
    end
  end
end
