require 'spec_helper'

module Bosh::Director
  describe Jobs::StartInstance do
    include Support::FakeLocks
    before { fake_locks }

    let(:manifest) { Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups }
    let(:deployment) { Models::Deployment.make(name: 'simple', manifest: YAML.dump(manifest)) }
    let(:vm_model) { Models::Vm.make(instance: instance_model, active: true, cid: 'test-vm-cid') }
    let(:task) { Models::Task.make(id: 42) }
    let(:task_writer) { TaskDBWriter.new(:event_output, task.id) }
    let(:event_log) { EventLog::Log.new(task_writer) }
    let(:cloud_config) { Models::Config.make(:cloud_with_manifest_v2) }
    let(:variables_interpolator) { ConfigServer::VariablesInterpolator.new }
    let(:event_log_stage) { instance_double('Bosh::Director::EventLog::Stage') }
    let(:vm_creator) { instance_double(VmCreator, create_for_instance_plan: nil) }
    let(:template_persister) { instance_double(RenderedTemplatesPersister, persist: nil) }
    let(:blobstore) { instance_double(Bosh::Blobstore::Client) }
    let(:local_dns_manager) { instance_double(LocalDnsManager, update_dns_record_for_instance: nil) }
    let(:state_applier) { instance_double(InstanceUpdater::StateApplier, apply: nil) }
    let!(:stemcell) { Bosh::Director::Models::Stemcell.make(name: 'stemcell-name', version: '3.0.2', cid: 'sc-302') }

    let!(:instance_spec) do
      {
        'stemcell' => {
          'name' => stemcell.name,
          'version' => stemcell.version,
        },
        'env' => { 'key1' => 'value1' },
      }
    end

    let(:instance_model) do
      Models::Instance.make(
        deployment: deployment,
        job: 'foobar',
        uuid: 'test-uuid',
        index: '1',
        state: 'stopped',
        spec_json: instance_spec.to_json,
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

    describe 'DelayedJob job class expectations' do
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
      Models::PersistentDisk.make(instance: instance_model, disk_cid: 'disk-cid')
      allow(instance_model).to receive(:active_vm).and_return(vm_model)

      allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
      allow(Config).to receive(:event_log).and_call_original
      allow(Config.event_log).to receive(:begin_stage).and_return(event_log_stage)
      allow(event_log_stage).to receive(:advance_and_track).and_yield

      allow(AgentClient).to receive(:with_agent_id).and_return(agent_client)
      allow(agent_client).to receive(:get_state).and_return({ 'job_state' => 'stopped' }, { 'job_state' => 'running' })

      allow(VmCreator).to receive(:new).and_return(vm_creator)
      allow(RenderedTemplatesPersister).to receive(:new).and_return(template_persister)
      allow(LocalDnsManager).to receive(:new).and_return(local_dns_manager)
      allow(InstanceUpdater::StateApplier).to receive(:new).and_return(state_applier)
    end

    describe 'perform' do
      it 'should start the instance' do
        job = Jobs::StartInstance.new(deployment.name, instance_model.id, {})
        expect(instance_model.state).to eq 'stopped'
        job.perform

        expect(state_applier).to have_received(:apply)
        expect(instance_model.reload.state).to eq 'started'
      end

      it 'obtains a deployment lock' do
        job = Jobs::StartInstance.new(deployment.name, instance_model.id, {})
        expect(job).to receive(:with_deployment_lock).with('simple').and_yield
        job.perform
      end

      it 'logs starting' do
        expect(Config.event_log).to receive(:begin_stage).with('Starting instance foobar').and_return(event_log_stage)
        expect(event_log_stage).to receive(:advance_and_track).with('foobar/test-uuid (1)').and_yield
        job = Jobs::StartInstance.new(deployment.name, instance_model.id, {})
        job.perform
      end

      it 'should send job templates and apply state to the VM' do
        job = Jobs::StartInstance.new(deployment.name, instance_model.id, {})
        job.perform

        expect(template_persister).to have_received(:persist).with(an_instance_of(DeploymentPlan::InstancePlanFromDB))
        expect(state_applier).to have_received(:apply)
        expect(instance_model.reload.update_completed).to eq(true)
      end

      context 'when applying state fails' do
        before do
          allow(state_applier).to receive(:apply).and_raise
        end

        it 'does not update the database' do
          job = Jobs::StartInstance.new(deployment.name, instance_model.id, {})
          expect { job.perform }.to raise_error

          expect(state_applier).to have_received(:apply)
          expect(instance_model.reload.update_completed).to eq(false)
          expect(instance_model.reload.state).to eq('stopped')
        end
      end

      context 'when the instance is already started' do
        let(:instance_model) do
          Models::Instance.make(deployment: deployment, job: 'foobar', state: 'started', spec_json: instance_spec.to_json)
        end

        context 'and the agent reports the state as running' do
          before do
            allow(agent_client).to receive(:get_state).and_return('job_state' => 'running')
          end

          it 'does nothing' do
            job = Jobs::StartInstance.new(deployment.name, instance_model.id, {})
            job.perform

            expect(state_applier).to_not have_received(:apply)
            expect(instance_model.reload.state).to eq 'started'
          end
        end

        context 'and the agent reports the state as not running' do
          it 'should start the instance' do
            job = Jobs::StartInstance.new(deployment.name, instance_model.id, {})
            job.perform

            expect(state_applier).to have_received(:apply)
            expect(instance_model.reload.state).to eq 'started'
          end
        end
      end

      context 'when the vm for the instance does not exist (due to hard stop)' do
        let(:vm_model) { nil }
        let(:expected_instance_plan) do
          instance_double(DeploymentPlan::InstancePlan, existing_instance: instance_model)
        end

        it 'requests a new vm with the right properties' do
          job = Jobs::StartInstance.new(deployment.name, instance_model.id, {})
          job.perform
          expect(vm_creator).to have_received(:create_for_instance_plan).with(
            an_instance_of(DeploymentPlan::InstancePlanFromDB),
            an_instance_of(DeploymentPlan::IpProvider),
            ['disk-cid'],
            deployment.tags,
            true,
          )
        end

        it 'should update dns records' do
          job = Jobs::StartInstance.new(deployment.name, instance_model.id, {})
          job.perform

          expect(local_dns_manager).to have_received(:update_dns_record_for_instance)
            .with(an_instance_of(DeploymentPlan::InstancePlanFromDB))
        end
      end

      context 'when the instance does not exist' do
        it 'raises an InstanceNotFound error' do
          job = Jobs::StartInstance.new(deployment.name, instance_model.id + 10000, {})
          expect { job.perform }.to raise_error(InstanceNotFound)
        end
      end

      context 'when the instance does belong to the deployment' do
        let(:instance_model) do
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
          job = Jobs::StartInstance.new(other_deployment.name, instance_model.id, {})
          expect { job.perform }.to raise_error(InstanceNotFound)
        end
      end
    end
  end
end
