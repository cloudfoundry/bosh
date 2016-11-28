require 'spec_helper'

module Bosh::Director
  describe InstanceUpdater do
    let(:ip_repo) { DeploymentPlan::InMemoryIpRepo.new(logger) }
    let(:ip_provider) { DeploymentPlan::IpProvider.new(ip_repo, [], logger) }
    let(:updater) { InstanceUpdater.new_instance_updater(ip_provider) }
    let(:vm_deleter) { instance_double(Bosh::Director::VmDeleter) }
    let(:vm_recreator) { instance_double(Bosh::Director::VmRecreator) }
    let(:agent_client) { instance_double(AgentClient) }
    let(:instance_model) { Models::Instance.make(uuid: 'uuid-1', deployment: deployment_model, state: instance_model_state, job: 'job-1', credentials: {'user' => 'secret'}, agent_id: 'scool', spec: {'stemcell' => {'name' => 'ubunut_1', 'version' => '8'}}) }
    let(:instance_model_state) { 'started' }
    let(:dns_manager) { DnsManagerProvider.create }
    let(:deployment_model) { Models::Deployment.make(name: 'deployment') }
    let(:instance) do
      az = DeploymentPlan::AvailabilityZone.new('az-1', {})
      vm_type = DeploymentPlan::VmType.new({'name' => 'small_vm'})
      stemcell = DeploymentPlan::Stemcell.new('ubuntu_stemcell', 'ubuntu_1', 'ubuntu', '8')
      instance = DeploymentPlan::Instance.new('job-1', 0, instance_desired_state, vm_type, [], stemcell, {}, false, deployment_model, {}, az, logger)
      instance.bind_existing_instance_model(instance_model)

      instance
    end
    let(:instance_desired_state) { 'stopped' }
    let(:job) { instance_double(DeploymentPlan::InstanceGroup, default_network: {}) }
    let(:instance_plan) do
      desired_instance = DeploymentPlan::DesiredInstance.new(job)
      instance_plan = DeploymentPlan::InstancePlan.new(existing_instance: instance_model, instance: instance, desired_instance: desired_instance, tags: tags)
      allow(instance_plan).to receive(:spec).and_return(DeploymentPlan::InstanceSpec.create_empty)

      instance_plan
    end
    let(:tags) do
      {'key1' => 'value1'}
    end
    let(:blobstore_client) { instance_double(Bosh::Blobstore::Client) }
    let(:rendered_templates_persistor) { instance_double(RenderedTemplatesPersister) }
    before do
      allow(Config).to receive_message_chain(:current_job, :username).and_return('user')
      allow(Config).to receive_message_chain(:current_job, :task_id).and_return('task-1', 'task-2')
      allow(Config).to receive_message_chain(:current_job, :event_manager).and_return(Api::EventManager.new({}))
      allow(Bosh::Director::App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore_client)
      allow(Bosh::Director::VmDeleter).to receive(:new).and_return(vm_deleter)
      allow(Bosh::Director::VmRecreator).to receive(:new).and_return(vm_recreator)
      allow(Bosh::Director::RenderedTemplatesPersister).to receive(:new).and_return(rendered_templates_persistor)
    end

    context 'when stopping instances' do
      before do
        allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).with({'user' => 'secret'}, 'scool').and_return(agent_client)
        allow(instance_plan).to receive(:changes).and_return([:state])
      end

      context 'when instance is currently started' do
        let(:instance_model_state) { 'started' }

        it 'drains, stops, snapshots, and persists rendered templates to the blobstore' do
          expect(Api::SnapshotManager).to receive(:take_snapshot)
          expect(agent_client).not_to receive(:apply)
          expect(agent_client).to receive(:stop)
          expect(agent_client).to receive(:drain).and_return(0.1)
          expect(rendered_templates_persistor).to receive(:persist).with(instance_plan)

          updater.update(instance_plan)
          expect(instance_model.state).to eq('stopped')
          expect(instance_model.update_completed).to eq true
          expect(Models::Event.count).to eq 2
        end
      end

      context 'when instance is currently stopped' do
        let(:instance_model_state) { 'stopped' }

        it 'does not try to stop, drain, or snapshot' do
          expect(Api::SnapshotManager).not_to receive(:take_snapshot)
          expect(agent_client).not_to receive(:apply)
          expect(agent_client).not_to receive(:stop)
          expect(agent_client).not_to receive(:drain)
          allow(rendered_templates_persistor).to receive(:persist).with(instance_plan)

          updater.update(instance_plan)
          expect(instance_model.state).to eq('stopped')
          expect(instance_model.update_completed).to eq true
          expect(Models::Event.count).to eq 2
        end

        it 'persists rendered templates to the blobstore' do
          expect(rendered_templates_persistor).to receive(:persist).with(instance_plan)

          updater.update(instance_plan)
        end
      end
    end

    context 'when starting instances' do
      let(:instance_desired_state) { 'started' }

      before do
        allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).with({'user' => 'secret'}, 'scool').and_return(agent_client)
        allow(instance_plan).to receive(:changes).and_return([:state])
      end

      context 'when instance is currently stopped' do
        let(:instance_model_state) { 'stopped' }

        let(:disk_manager) { instance_double(DiskManager) }
        before { allow(DiskManager).to receive(:new).and_return(disk_manager) }

        let(:state_applier) { instance_double(InstanceUpdater::StateApplier) }
        before { allow(InstanceUpdater::StateApplier).to receive(:new).and_return(state_applier) }

        it 'does NOT drain, stop, snapshot, but persists rendered templates to the blobstore' do
          # https://www.pivotaltracker.com/story/show/121721619
          expect(Api::SnapshotManager).to_not receive(:take_snapshot)
          expect(agent_client).to_not receive(:stop)
          expect(agent_client).to_not receive(:drain)

          allow(updater).to receive(:needs_recreate?).and_return(false)
          allow(disk_manager).to receive(:update_persistent_disk)
          allow(job).to receive(:update)
          allow(instance).to receive(:update_instance_settings)
          expect(state_applier).to receive(:apply)
          expect(rendered_templates_persistor).to receive(:persist).with(instance_plan).twice

          updater.update(instance_plan)

          expect(instance_model.update_completed).to eq true
          expect(Models::Event.count).to eq 2
          expect(Models::Event.all[1].error).to be_nil
        end

        context 'when an instance needs to be recreated' do
          before do
            allow(updater).to receive(:needs_recreate?).and_return(true)
            allow(disk_manager).to receive(:update_persistent_disk)
            allow(disk_manager).to receive(:unmount_disk_for)
            allow(job).to receive(:update)
            allow(vm_deleter).to receive(:delete_for_instance)
          end

          it 'recreates correctly, and persists rendered templates to the blobstore' do
            expect(vm_recreator).to receive(:recreate_vm).with(anything, anything, tags)
            expect(state_applier).to receive(:apply)
            expect(rendered_templates_persistor).to receive(:persist).with(instance_plan).twice

            updater.update(instance_plan)
          end
        end
      end
    end

    context 'when changing DNS' do
      before do
        allow(instance_plan).to receive(:changes).and_return([:dns])
        allow(DnsManagerProvider).to receive(:create).and_return(dns_manager)
      end

      it 'should exit early without interacting at all with the agent, and does NOT persist rendered templates to the blobstore' do
        instance_model.update(dns_record_names: ['old.dns.record'])
        expect(instance_model.state).to eq('started')
        expect(Models::Event.count).to eq 0

        expect(AgentClient).not_to receive(:with_vm_credentials_and_agent_id)

        expect(dns_manager).to receive(:publish_dns_records).twice

        subnet_spec = {
          'range' => '10.10.10.0/24',
          'gateway' => '10.10.10.1',
        }
        subnet = DeploymentPlan::ManualNetworkSubnet.parse('my-network', subnet_spec, ['az-1'], [])
        network = DeploymentPlan::ManualNetwork.new('my-network', [subnet], logger)
        reservation = ExistingNetworkReservation.new(instance_model, network, '10.10.10.10', :dynamic)
        instance_plan.network_plans = [DeploymentPlan::NetworkPlanner::Plan.new(reservation: reservation, existing: true)]

        expect(Bosh::Director::RenderedTemplatesPersister).to_not receive(:persist).with(logger, blobstore_client, instance_plan)

        updater.update(instance_plan)

        expect(instance_model.dns_record_names).to eq ['old.dns.record', '0.job-1.my-network.deployment.bosh', 'uuid-1.job-1.my-network.deployment.bosh']
        expect(instance_model.update_completed).to eq true
        expect(Models::Event.count).to eq 2
      end
    end

    context 'when the VM does not get recreated' do
      let(:disk_manager) { instance_double(DiskManager) }
      before { allow(DiskManager).to receive(:new).and_return(disk_manager) }

      let(:state_applier) { instance_double(InstanceUpdater::StateApplier) }
      before { allow(InstanceUpdater::StateApplier).to receive(:new).and_return(state_applier) }

      it 'updates the instance settings' do
        allow(instance_plan).to receive(:changes).and_return([:trusted_certs])
        allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).with({'user' => 'secret'}, 'scool').and_return(agent_client)

        allow(instance_plan).to receive(:networks_changed?).and_return(false)
        allow(instance_plan).to receive(:needs_shutting_down?).and_return(false)
        allow(instance_plan).to receive(:cloud_properties_changed?).and_return(false)

        allow(instance_plan).to receive(:already_detached?).and_return(true)
        allow(disk_manager).to receive(:update_persistent_disk)
        allow(state_applier).to receive(:apply)
        allow(job).to receive(:update)
        allow(rendered_templates_persistor).to receive(:persist).with(instance_plan)

        allow(logger).to receive(:debug)

        expect(instance).to receive(:update_instance_settings)
        updater.update(instance_plan)
      end
    end

    context 'when something goes wrong in the update procedure' do
      before do
        allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).with({'user' => 'secret'}, 'scool').and_return(agent_client)
        allow(instance_plan).to receive(:changes).and_return([:state])
        allow(rendered_templates_persistor).to receive(:persist)
      end

      it 'should always add an event recording the error' do
        expect(Models::Event.count).to eq 0

        drain_error = RpcRemoteException.new('Oh noes!')
        expect(agent_client).to receive(:drain).and_raise(drain_error)

        expect { updater.update(instance_plan) }.to raise_error drain_error
        expect(Models::Event.map(&:error)).to eq([nil, 'Oh noes!'])
      end
    end
  end
end
