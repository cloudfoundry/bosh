require 'spec_helper'

module Bosh::Director
  describe Jobs::StartInstance do
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
    let(:event_log_stage) { instance_double('Bosh::Director::EventLog::Stage') }

    let(:instance) do
      Models::Instance.make(
        deployment: deployment,
        job: 'foobar',
        uuid: 'test-uuid',
        index: '1',
        state: 'stopped',
      )
    end

    let(:agent_client) do
      instance_double(
        AgentClient,
        run_script: nil,
        start: nil,
        apply: nil,
        get_state: { 'job_state' => 'running' },
      )
    end

    describe 'DJ job class expectations' do
      let(:job_type) { :start_instance }
      let(:queue) { :normal }
      it_behaves_like 'a DJ job'
    end

    let(:deployment_plan_instance) do
      instance_double(
        DeploymentPlan::Instance,
        template_hashes: nil,
        rendered_templates_archive: nil,
        configuration_hash: nil,
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

      allow(AgentClient).to receive(:with_agent_id).and_return(agent_client)
    end

    describe 'perform' do
      it 'should start the instance' do
        job = Jobs::StartInstance.new(deployment.name, instance.id, {})
        expect(instance.state).to eq 'stopped'

        job.perform

        expect(agent_client).to have_received(:run_script).with('pre-start', {})
        expect(agent_client).to have_received(:start)
        expect(agent_client).to have_received(:run_script).with('post-start', {})
        expect(instance.reload.state).to eq 'started'
      end

      it 'obtains a deployment lock' do
        job = Jobs::StartInstance.new(deployment.name, instance.id, {})
        expect(job).to receive(:with_deployment_lock).with('simple').and_yield
        job.perform
      end

      it 'logs starting' do
        expect(Config.event_log).to receive(:begin_stage).with('Starting instance foobar').and_return(event_log_stage)
        expect(event_log_stage).to receive(:advance_and_track).with('foobar/test-uuid (1)').and_yield
        job = Jobs::StartInstance.new(deployment.name, instance.id, {})
        job.perform
      end

      context 'when the instance is already started' do
        let(:instance) { Models::Instance.make(deployment: deployment, job: 'foobar', state: 'started') }

        it 'does nothing' do
          job = Jobs::StartInstance.new(deployment.name, instance.id, {})
          job.perform

          expect(agent_client).to_not have_received(:run_script).with('pre-start', anything)
          expect(agent_client).to_not have_received(:start)
          expect(agent_client).to_not have_received(:run_script).with('post-start', {})
          expect(instance.reload.state).to eq 'started'
        end
      end

      context 'when the instance does not exist' do
        it 'raises an InstanceNotFound error' do
          job = Jobs::StartInstance.new(deployment.name, instance.id + 10000, {})
          expect { job.perform }.to raise_error(InstanceNotFound)
        end
      end

      context 'when the instance does belong to the deployment' do
        let(:instance) do
          Models::Instance.make(
            deployment: deployment,
            job: 'foobar',
            uuid: 'test-uuid',
            index: '1',
            state: 'stopped',
          )
        end
        let(:other_deployment) { Models::Deployment.make(name: 'other', manifest: YAML.dump(manifest)) }

        it 'raises an InstanceNotFound error' do
          job = Jobs::StartInstance.new(other_deployment.name, instance.id, {})
          expect { job.perform }.to raise_error(InstanceNotFound)
        end
      end
    end
  end
end
