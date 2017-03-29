require 'spec_helper'
require 'bosh/director/stopper'

module Bosh::Director
  describe Stopper do
    subject(:stopper) { described_class.new(instance_plan, target_state, config, logger) }
    let(:vm_model) { Models::Vm.make(cid: 'vm-cid') }
    let(:instance_model) do
      is = Models::Instance.make(spec: spec)
      is.add_vm vm_model
      is.update(active_vm: vm_model)
    end

    let(:agent_client) { instance_double('Bosh::Director::AgentClient') }
    before { allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).with(instance_model.credentials, instance_model.agent_id).and_return(agent_client) }
    let(:target_state) { 'fake-target-state' }
    let(:config) { Config }
    let(:skip_drain) { false }
    let(:job) { instance_double(DeploymentPlan::InstanceGroup,
      name: 'fake-job-name',
      default_network: {}
    ) }
    let(:instance) { instance_double(DeploymentPlan::Instance,
      job_name: job.name,
      model: instance_model,
      availability_zone: DeploymentPlan::AvailabilityZone.new('az', {}),
      index: 0,
      uuid: SecureRandom.uuid,
      rendered_templates_archive: nil,
      configuration_hash: {'fake-spec' => true},
      template_hashes: [],
      current_job_state: current_job_state,
      deployment_model: deployment_model
    ) }
    let(:deployment_model) { instance_double(Bosh::Director::Models::Deployment, name: 'fake-deployment') }
    let(:current_job_state) {'running'}
    let(:desired_instance) { DeploymentPlan::DesiredInstance.new(job) }
    let(:instance_plan) do
      DeploymentPlan::InstancePlan.new(existing_instance: instance_model, instance: instance, desired_instance: desired_instance, skip_drain: skip_drain)
    end
    let(:spec) do
      {
        'vm_type' => {
          'name' => 'vm-type-name',
          'cloud_properties' => {}
        },
        'stemcell' => {
          'name' => 'stemcell-name',
          'version' => '2.0.6'
        },
        'networks' => {},
      }
    end
    let(:drain_spec) do
      {
        'networks' => {},
        'template_hashes' =>[],
        'configuration_hash' =>{'fake-spec' =>true}
      }
    end

    before do
      allow(instance).to receive(:current_networks)
      instance_spec = DeploymentPlan::InstanceSpec.new(spec, instance)
      allow(instance_plan).to receive(:spec).and_return(instance_spec)
    end

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

      context 'when it is instance with unresponsive agent' do
        let(:current_job_state) {'unresponsive'}

        it 'does not drain and stop' do
          expect(agent_client).to_not receive(:drain)
          expect(stopper).to_not receive(:sleep)
          expect(agent_client).to_not receive(:stop)
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
        before { instance_model.active_vm_id = nil }

        it 'does not drain and stop' do
          expect(agent_client).to_not receive(:drain)
          expect(stopper).to_not receive(:sleep)
          expect(agent_client).to_not receive(:stop)
          stopper.stop
        end
      end

      context 'when shutting down' do
        before { allow(subject).to receive_messages(needs_drain_to_migrate_data?: true) }

        context 'with static drain' do
          it 'sends shutdown with next apply spec and then stops services' do
            expect(agent_client).to receive(:drain).with('shutdown', drain_spec).and_return(1).ordered
            expect(subject).to receive(:sleep).with(1).ordered
            expect(agent_client).to receive(:stop).with(no_args).ordered
            subject.stop
          end
        end

        context 'with dynamic drain' do
          it 'sends shutdown with next apply spec and then stops services' do
            expect(agent_client).to receive(:drain).with('shutdown', drain_spec).and_return(-2).ordered
            expect(subject).to receive(:wait_for_dynamic_drain).with(-2).ordered
            expect(agent_client).to receive(:stop).with(no_args).ordered
            subject.stop
          end
        end
      end

      context 'when updating' do
        before { allow(subject).to receive_messages(needs_drain_to_migrate_data?: false) }

        context 'with static drain' do
          it 'sends update with next apply spec and then stops services' do
            expect(agent_client).to receive(:drain).with('update', drain_spec).and_return(1).ordered
            expect(subject).to receive(:sleep).with(1).ordered
            expect(agent_client).to receive(:stop).with(no_args).ordered
            subject.stop
          end
        end

        context 'with dynamic drain' do
          it 'sends update with next apply spec and then stops services' do
            expect(agent_client).to receive(:drain).with('update', drain_spec).and_return(-2).ordered
            expect(subject).to receive(:wait_for_dynamic_drain).with(-2).ordered
            expect(agent_client).to receive(:stop).with(no_args).ordered
            subject.stop
          end

          it 'waits on the agent' do
            allow(agent_client).to receive(:stop)
            allow(agent_client).to receive(:drain).with('status').and_return(-1, 0)

            expect(agent_client).to receive(:drain).with('update', drain_spec).and_return(-2).ordered
            expect(subject).to receive(:sleep).with(2).ordered
            expect(subject).to receive(:sleep).with(1).ordered
            subject.stop
          end
        end
      end

      context 'when the instance needs shutting down' do
        before do
          allow(instance_plan).to receive(:needs_shutting_down?).and_return(true)
        end

        it 'drains with shutdown' do
          expect(agent_client).to receive(:drain).with('shutdown', drain_spec).and_return(1).ordered
          expect(agent_client).to receive(:stop).ordered
          subject.stop
        end
      end

      context 'when the persistent disks have changed' do
        before do
          allow(instance_plan).to receive(:needs_shutting_down?).and_return(false)
          allow(instance_plan).to receive(:persistent_disk_changed?).and_return(true)
          instance_plan.existing_instance.add_persistent_disk(Models::PersistentDisk.make)
        end

        it 'drains with shutdown' do
          expect(agent_client).to receive(:drain).with('shutdown', drain_spec).and_return(1).ordered
          expect(agent_client).to receive(:stop).ordered
          subject.stop
        end
      end

      context 'when networks have changed' do
        before do
          allow(instance_plan).to receive(:needs_shutting_down?).and_return(false)
          allow(instance_plan).to receive(:persistent_disk_changed?).and_return(false)

          subnet = DeploymentPlan::DynamicNetworkSubnet.new('a.b.c.d', {}, ['az'])
          network = DeploymentPlan::DynamicNetwork.new('dynamic', [subnet], logger)
          reservation = DesiredNetworkReservation.new_dynamic(instance_model, network)
          instance_plan.network_plans = [DeploymentPlan::NetworkPlanner::Plan.new(reservation: reservation)]
        end

        it 'drains with shutdown' do
          expect(agent_client).to receive(:drain).with('shutdown', drain_spec).and_return(1).ordered
          expect(agent_client).to receive(:stop).ordered
          subject.stop
        end
      end

      context 'when "target state" is "detached"' do
        let(:target_state) { 'detached' }

        it 'drains with shutdown' do
          expect(agent_client).to receive(:drain).with('shutdown', drain_spec).and_return(1).ordered
          expect(agent_client).to receive(:stop).ordered
          subject.stop
        end
      end

      context 'when "target state" is "stopped"' do
        let(:target_state) { 'stopped' }

        it 'drains with shutdown' do
          expect(agent_client).to receive(:drain).with('shutdown', drain_spec).and_return(1).ordered
          expect(agent_client).to receive(:stop).ordered
          subject.stop
        end
      end

      context 'when "target state" is "started"' do
        let(:target_state) { 'started' }

        before do
          allow(instance_plan).to receive(:needs_shutting_down?).and_return(false)
          allow(instance_plan).to receive(:persistent_disk_changed?).and_return(false)
        end

        it 'does not shutdown' do
          expect(agent_client).to receive(:drain).with('update', drain_spec).and_return(1).ordered
          expect(agent_client).to receive(:stop).ordered
          subject.stop
        end
      end
    end
  end
end
