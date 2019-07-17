require 'spec_helper'

module Bosh::Director
  describe Jobs::StopInstance do
    describe 'DJ job class expectations' do
      let(:job_type) { :stop_instance }
      let(:queue) { :normal }
      it_behaves_like 'a DJ job'
    end
    include Support::FakeLocks
    before { fake_locks }

    let(:manifest) { Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups }
    let(:deployment) { Models::Deployment.make(name: 'simple', manifest: YAML.dump(manifest)) }
    let(:vm_model) { Models::Vm.make(instance: instance, active: true, cid: 'test-vm-cid') }
    let(:task) { Models::Task.make(id: 42) }
    let(:task_writer) { TaskDBWriter.new(:event_output, task.id) }
    let(:event_log) { EventLog::Log.new(task_writer) }
    let(:cloud_config) { Models::Config.make(:cloud_with_manifest_v2) }
    let(:variables_interpolator) { ConfigServer::VariablesInterpolator.new }
    let(:unmount_instance_disk_step) { instance_double(DeploymentPlan::Steps::UnmountInstanceDisksStep, perform: nil) }
    let(:detach_instance_disk_step) { instance_double(DeploymentPlan::Steps::DetachInstanceDisksStep, perform: nil) }
    let(:delete_vm_step) { instance_double(DeploymentPlan::Steps::DeleteVmStep, perform: nil) }
    let(:event_log_stage) { instance_double('Bosh::Director::EventLog::Stage') }
    let(:agent_client) { instance_double(AgentClient, run_script: nil, drain: 0, stop: nil) }
    let!(:stemcell) { Bosh::Director::Models::Stemcell.make(name: 'stemcell-name', version: '3.0.2', cid: 'sc-302') }
    let(:deployment_plan_instance) do
      instance_double(DeploymentPlan::Instance,
                      template_hashes: nil,
                      rendered_templates_archive: nil,
                      configuration_hash: nil)
    end
    let(:event_manager) { Bosh::Director::Api::EventManager.new(true) }

    let!(:spec) do
      {
        'vm_type' => {
          'name' => 'vm-type-name',
          'cloud_properties' => {},
        },
        'stemcell' => {
          'name' => stemcell.name,
          'version' => stemcell.version,
        },
        'networks' => {},
      }
    end

    let!(:instance) do
      Models::Instance.make(
        deployment: deployment,
        job: 'foobar',
        uuid: 'test-uuid',
        index: '1',
        spec_json: spec.to_json,
      )
    end

    before do
      Models::VariableSet.make(deployment: deployment)
      deployment.add_cloud_config(cloud_config)
      release = Models::Release.make(name: 'bosh-release')
      release_version = Models::ReleaseVersion.make(version: '0.1-dev', release: release)
      template1 = Models::Template.make(name: 'foobar', release: release)
      release_version.add_template(template1)
      allow(instance).to receive(:active_vm).and_return(vm_model)

      allow(Config).to receive(:event_log).and_call_original
      allow(Config.event_log).to receive(:begin_stage).and_return(event_log_stage)
      allow(event_log_stage).to receive(:advance_and_track).and_yield
      allow(Config).to receive_message_chain(:current_job, :event_manager).and_return(event_manager)
      allow(Config).to receive_message_chain(:current_job, :username).and_return('user')
      allow(Config).to receive_message_chain(:current_job, :task_id).and_return('5')

      allow(AgentClient).to receive(:with_agent_id).and_return(agent_client)
      allow(agent_client).to receive(:get_state).and_return({ 'job_state' => 'running' }, { 'job_state' => 'stopped' })
      allow(Api::SnapshotManager).to receive(:take_snapshot)
      allow(DeploymentPlan::Steps::UnmountInstanceDisksStep).to receive(:new).and_return(unmount_instance_disk_step)
      allow(DeploymentPlan::Steps::DetachInstanceDisksStep).to receive(:new).and_return(detach_instance_disk_step)
      allow(DeploymentPlan::Steps::DeleteVmStep).to receive(:new).and_return(delete_vm_step)
    end

    describe 'perform' do
      it 'should stop the instance' do
        job = Jobs::StopInstance.new(deployment.name, instance.id, {})
        expect(instance.state).to eq 'started'

        job.perform

        pre_stop_env = { 'env' => {
          'BOSH_VM_NEXT_STATE' => 'keep',
          'BOSH_INSTANCE_NEXT_STATE' => 'keep',
          'BOSH_DEPLOYMENT_NEXT_STATE' => 'keep',
        } }

        expect(agent_client).to have_received(:run_script).with('pre-stop', pre_stop_env)
        expect(agent_client).to have_received(:drain).with('shutdown', anything)
        expect(agent_client).to have_received(:stop)
        expect(agent_client).to have_received(:run_script).with('post-stop', {})
        expect(instance.reload.state).to eq 'stopped'
      end

      it 'should stop the instance and detach the VM when --hard is specified' do
        job = Jobs::StopInstance.new(deployment.name, instance.id, 'hard' => true)
        expect(instance.state).to eq 'started'

        job.perform

        pre_stop_env = { 'env' => {
          'BOSH_VM_NEXT_STATE' => 'delete',
          'BOSH_INSTANCE_NEXT_STATE' => 'keep',
          'BOSH_DEPLOYMENT_NEXT_STATE' => 'keep',
        } }

        expect(agent_client).to have_received(:run_script).with('pre-stop', pre_stop_env)
        expect(agent_client).to have_received(:drain).with('shutdown', anything)
        expect(agent_client).to have_received(:stop)
        expect(agent_client).to have_received(:run_script).with('post-stop', {})
        expect(unmount_instance_disk_step).to have_received(:perform)
        expect(detach_instance_disk_step).to have_received(:perform)
        expect(delete_vm_step).to have_received(:perform)
        expect(instance.reload.state).to eq 'detached'
      end

      it 'takes a snapshot of the instance' do
        job = Jobs::StopInstance.new(deployment.name, instance.id, 'hard' => false)
        job.perform
        expect(Api::SnapshotManager).to have_received(:take_snapshot).with(instance, clean: true)
      end

      it 'obtains a deployment lock' do
        job = Jobs::StopInstance.new(deployment.name, instance.id, 'hard' => false)
        expect(job).to receive(:with_deployment_lock).with('simple').and_yield
        job.perform
      end

      it 'logs stopping and detaching' do
        expect(Config.event_log).to receive(:begin_stage).with('Stopping instance foobar').and_return(event_log_stage)
        expect(event_log_stage).to receive(:advance_and_track).with('foobar/test-uuid (1)').and_yield

        expect(Config.event_log).to receive(:begin_stage).with('Deleting VM').and_return(event_log_stage)
        expect(event_log_stage).to receive(:advance_and_track).with('test-vm-cid').and_yield
        job = Jobs::StopInstance.new(deployment.name, instance.id, 'hard' => true)

        expect { job.perform }.to change { Bosh::Director::Models::Event.count }.from(0).to(2)
        expect(Bosh::Director::Models::Event.first.action).to eq 'stop'
      end

      context 'when detaching the VM fails in a hard stop' do
        before do
          allow(unmount_instance_disk_step).to receive(:perform).and_raise(StandardError.new('failed to detach vm'))
        end

        it 'still reports the vm as stopped' do
          job = Jobs::StopInstance.new(deployment.name, instance.id, 'hard' => true)

          expect { job.perform }.to raise_error(StandardError)
          expect(instance.reload.state).to eq 'stopped'
        end
      end

      context 'when the instance is already soft stopped' do
        let(:instance) { Models::Instance.make(deployment: deployment, job: 'foobar', state: 'stopped', spec_json: spec.to_json) }

        it 'detaches the vm if --hard is specified' do
          job = Jobs::StopInstance.new(deployment.name, instance.id, 'hard' => true)
          job.perform

          expect(instance.reload.state).to eq 'detached'
        end

        it 'does nothing' do
          job = Jobs::StopInstance.new(deployment.name, instance.id, 'hard' => false)
          job.perform

          expect(agent_client).to_not have_received(:run_script).with('pre-stop', anything)
          expect(agent_client).to_not have_received(:drain).with('shutdown', anything)
          expect(agent_client).to_not have_received(:stop)
          expect(agent_client).to_not have_received(:run_script).with('post-stop', {})
          expect(instance.reload.state).to eq 'stopped'
          expect(event_manager).to_not receive(:create_event)
        end
      end

      context 'when the instance is already hard stopped' do
        let(:instance) { Models::Instance.make(deployment: deployment, job: 'foobar', state: 'detached') }

        it 'does nothing' do
          job = Jobs::StopInstance.new(deployment.name, instance.id, 'hard' => true)
          job.perform

          expect(agent_client).to_not have_received(:run_script).with('pre-stop', anything)
          expect(agent_client).to_not have_received(:drain).with('shutdown', anything)
          expect(agent_client).to_not have_received(:stop)
          expect(agent_client).to_not have_received(:run_script).with('post-stop', {})
          expect(unmount_instance_disk_step).to_not have_received(:perform)
          expect(detach_instance_disk_step).to_not have_received(:perform)
          expect(delete_vm_step).to_not have_received(:perform)
          expect(instance.reload.state).to eq 'detached'
          expect(event_manager).to_not receive(:create_event)
        end
      end

      context 'skip-drain' do
        it 'skips drain' do
          job = Jobs::StopInstance.new(deployment.name, instance.id, 'skip_drain' => true)
          job.perform
          expect(agent_client).not_to have_received(:run_script).with('pre-stop', anything)
          expect(agent_client).not_to have_received(:drain)
          expect(agent_client).to have_received(:stop)
          expect(agent_client).to have_received(:run_script).with('post-stop', {})
          expect(instance.reload.state).to eq 'stopped'
        end
      end

      context 'when the agent is unresponsive' do
        before do
          allow(agent_client).to receive(:get_state).and_raise(Bosh::Director::RpcTimeout)
        end

        it 'ignores any unresponsive agent state if ignore-unresponsive-agent is set to true' do
          job = Jobs::StopInstance.new(deployment.name, instance.id, 'ignore_unresponsive_agent' => true, 'hard' => true)
          expect { job.perform }.to_not raise_error

          expect(agent_client).to_not have_received(:run_script).with('pre-stop', anything)
          expect(agent_client).to_not have_received(:drain)
          expect(agent_client).to_not have_received(:stop)
          expect(agent_client).to_not have_received(:run_script).with('post-stop', {})
          expect(unmount_instance_disk_step).to_not have_received(:perform)
          expect(detach_instance_disk_step).to_not have_received(:perform)
          expect(delete_vm_step).to have_received(:perform)
          expect(instance.reload.state).to eq 'detached'
        end

        it 'raises an error' do
          job = Jobs::StopInstance.new(deployment.name, instance.id, 'ignore_unresponsive_agent' => false)
          expect { job.perform }.to raise_error

          expect(agent_client).to_not have_received(:run_script).with('pre-stop', anything)
          expect(agent_client).to_not have_received(:drain)
          expect(agent_client).to_not have_received(:stop)
          expect(agent_client).to_not have_received(:run_script).with('post-stop', {})
          expect(instance.reload.state).to eq 'started'
        end
      end
    end
  end
end
