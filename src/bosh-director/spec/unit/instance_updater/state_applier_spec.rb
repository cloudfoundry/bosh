require 'spec_helper'

module Bosh::Director
  describe InstanceUpdater::StateApplier do
    include Support::StemcellHelpers

    subject(:state_applier) { InstanceUpdater::StateApplier.new(instance_plan, agent_client, rendered_job_templates_cleaner, logger, options) }

    let(:options) { {} }
    let(:instance_plan) do
      DeploymentPlan::InstancePlan.new({
          existing_instance: instance_model,
          desired_instance: DeploymentPlan::DesiredInstance.new(job),
          instance: instance,
        })
    end

    let(:network_spec) do
      {'name' => 'default', 'subnets' => [{'cloud_properties' => {'foo' => 'bar'}, 'az' => 'foo-az'}]}
    end
    let(:network) { DeploymentPlan::DynamicNetwork.parse(network_spec, [availability_zone], logger) }

    let(:job) do
      job = instance_double('Bosh::Director::DeploymentPlan::InstanceGroup',
        name: 'fake-job',
        spec: {'name' => 'job'},
        canonical_name: 'job',
        instances: ['instance0'],
        default_network: {'gateway' => 'default'},
        vm_type: DeploymentPlan::VmType.new({'name' => 'fake-vm-type'}),
        vm_extensions: [],
        stemcell: make_stemcell({:name => 'fake-stemcell-name', :version => '1.0'}),
        env: DeploymentPlan::Env.new({'key' => 'value'}),
        package_spec: {},
        persistent_disk_collection: DeploymentPlan::PersistentDiskCollection.new(logger),
        is_errand?: false,
        resolved_links: {},
        compilation?: false,
        jobs: [],
        update_spec: update_config.to_hash,
        properties: {},
        lifecycle: DeploymentPlan::InstanceGroup::DEFAULT_LIFECYCLE_PROFILE,
      )
    end
    let(:update_config) do
      DeploymentPlan::UpdateConfig.new({'canaries' => 1, 'max_in_flight' => 1, 'canary_watch_time' => '1000-2000', 'update_watch_time' => update_watch_time})
    end
    let(:plan) do
      instance_double('Bosh::Director::DeploymentPlan::Planner', {
          name: 'fake-deployment',
          model: deployment,
        })
    end
    let(:deployment) { Bosh::Director::Models::Deployment.make(name: 'fake-deployment') }
    let(:availability_zone) { Bosh::Director::DeploymentPlan::AvailabilityZone.new('foo-az', {'a' => 'b'}) }
    let(:instance) { DeploymentPlan::Instance.create_from_job(job, 0, instance_state, plan, {}, availability_zone, logger) }
    let(:instance_model) { Models::Instance.make(deployment: deployment, state: instance_model_state, uuid: 'uuid-1') }
    let(:blobstore) { instance_double(Bosh::Blobstore::Client) }
    let(:agent_client) { instance_double(AgentClient) }
    let(:rendered_job_templates_cleaner) { instance_double(RenderedJobTemplatesCleaner) }
    let(:instance_state) { 'started' }
    let(:instance_model_state) { 'stopped' }
    let(:job_state) { 'running' }
    let(:update_watch_time) { '1000-2000' }

    before do
      reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network)
      reservation.resolve_ip('192.168.0.10')

      instance_plan.network_plans << DeploymentPlan::NetworkPlanner::Plan.new(reservation: reservation)
      instance.bind_existing_instance_model(instance_model)

      allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).with(instance_model.credentials, instance_model.agent_id).and_return(agent_client)
      allow(agent_client).to receive(:apply)
      allow(agent_client).to receive(:run_script)
      allow(agent_client).to receive(:start)
      allow(agent_client).to receive(:get_state).and_return({'job_state' => job_state})
      allow(rendered_job_templates_cleaner).to receive(:clean)
      allow(state_applier).to receive(:sleep)
    end

    it 'runs the pre-start, start and post-start scripts in order' do
      expect(agent_client).to receive(:run_script).with('pre-start', {}).ordered
      expect(agent_client).to receive(:start).ordered
      expect(agent_client).to receive(:run_script).with('post-start', {}).ordered

      state_applier.apply(update_config)
    end

    it 'updates instance spec' do
      expect(agent_client).to receive(:apply).with(instance_plan.spec.as_apply_spec)
      state_applier.apply(update_config)
      expect(instance_model.spec).to eq(instance_plan.spec.full_spec)
    end

    it 'can skip post start if run_post_start is false' do
      expect(agent_client).to_not receive(:run_script).with('post-start', {})
      state_applier.apply(update_config, false)
    end

    it 'runs post start by default' do
      expect(agent_client).to receive(:run_script).with('post-start', {})
      state_applier.apply(update_config)
    end

    it 'cleans rendered templates after applying' do
      expect(agent_client).to receive(:apply).ordered
      expect(rendered_job_templates_cleaner).to receive(:clean).ordered
      state_applier.apply(update_config)
    end

    it 'should stop execution if task was canceled' do
      task = Bosh::Director::Models::Task.make(:id => 42, :state => 'cancelling')
      base_job = Jobs::BaseJob.new
      allow(base_job).to receive(:task_id).and_return(task.id)
      allow(Config).to receive(:current_job).and_return(base_job)
      Config.instance_variable_set(:@current_job, base_job)
      expect(logger).to receive(:info).with('Applying VM state').ordered
      expect(logger).to receive(:info).with('Running pre-start for fake-job/uuid-1 (0)').ordered
      expect(logger).to receive(:info).with('Starting instance fake-job/uuid-1 (0)').ordered
      expect(logger).to receive(:debug).with('Task was cancelled. Stop waiting for the desired state').ordered

      expect { state_applier.apply(update_config) }.to raise_error Bosh::Director::TaskCancelled, 'Task 42 cancelled'
    end

    context 'when instance state is stopped' do
      let(:instance_state) { 'stopped' }
      let(:job_state) { 'stopped' }

      it 'does not run the start script' do
        expect(agent_client).to_not receive(:run_script)
        expect(agent_client).to_not receive(:start)
        state_applier.apply(update_config)
      end
    end

    describe 'waiting for job to be running' do
      let(:job_state) { 'stopped' }

      context 'scheduling' do
        let(:update_watch_time) { '1000-91000' }

        it 'divides the range into 10 equal steps' do
          expect(state_applier).to receive(:sleep).with(10.0).exactly(9).times
          expect { state_applier.apply(update_config) }.to raise_error
        end

        context 'when the interval length is less than 10 seconds' do
          let(:update_watch_time) { '1000-8000' }

          it 'divides the interval into 1 second steps' do
            expect(state_applier).to receive(:sleep).with(1.0).exactly(8).times
            expect { state_applier.apply(update_config) }.to raise_error
          end
        end

        context 'when the interval length is longer than 150 seconds' do
          let(:update_watch_time) { '1000-301000' }

          it 'divides the interval into 15 seconds steps' do
            expect(state_applier).to receive(:sleep).with(15.0).exactly(20).times
            expect { state_applier.apply(update_config) }.to raise_error
          end
        end
      end

      context 'when trying to start a job' do
        context 'when job does not start within max_watch_time' do
          before do
            allow(agent_client).to receive(:get_state).and_return({'job_state' => 'stopped', 'processes' => [{'state' => 'failing', 'name' => 'broken_template'}]}, {'job_state' => 'stopped', 'processes' => [{'state' => 'failing', 'name' => 'broken_template'}]})
          end

          it 'raises AgentJobNotRunning' do
            expect(state_applier).to receive(:sleep).with(1.0).twice
            expect(agent_client).to_not receive(:run_script).with('post-start', {})

            expect { state_applier.apply(update_config) }.to raise_error AgentJobNotRunning, "'fake-job/uuid-1 (0)' is not running after update. Review logs for failed jobs: broken_template"
          end

          it 'does not update state on the instance model' do
            expect(instance.model.state).to eq('stopped')

            expect { state_applier.apply(update_config) }.to raise_error AgentJobNotRunning
            expect(instance.model.state).to eq('stopped')
          end
        end

        context 'when a stopped job does not have processes defined' do
          before do
            allow(agent_client).to receive(:get_state).and_return({'job_state' => 'stopped'})
          end

          it 'raises AgentJobNotRunning with no failing jobs' do
            expect { state_applier.apply(update_config) }.to raise_error AgentJobNotRunning, "'fake-job/uuid-1 (0)' is not running after update."
          end
        end

        context 'when the job successfully starts' do
          before do
            allow(agent_client).to receive(:get_state).and_return({'job_state' => 'stopped', 'processes' => [{'state' => 'failing', 'name' => 'broken_template'}]}, {'job_state' => 'running', 'processes' => [{'state' => 'starting', 'name' => 'template'}]})
            allow(state_applier).to receive(:sleep)
            allow(agent_client).to receive(:run_script)
          end

          it 'runs the post-start script after instance is in desired state' do
            expect(state_applier).to receive(:sleep).with(1.0).twice
            expect(agent_client).to receive(:run_script).with('post-start', {})

            state_applier.apply(update_config)
          end

          it 'logs while waiting until instance is in desired state' do
            expect(logger).to receive(:info).with('Applying VM state').ordered
            expect(logger).to receive(:info).with('Running pre-start for fake-job/uuid-1 (0)').ordered
            expect(logger).to receive(:info).with('Starting instance fake-job/uuid-1 (0)').ordered
            expect(logger).to receive(:info).with('Waiting for 1.0 seconds to check fake-job/uuid-1 (0) status').ordered
            expect(logger).to receive(:info).with('Checking if fake-job/uuid-1 (0) has been updated after 1.0 seconds').ordered
            expect(logger).to receive(:info).with('Waiting for 1.0 seconds to check fake-job/uuid-1 (0) status').ordered
            expect(logger).to receive(:info).with('Checking if fake-job/uuid-1 (0) has been updated after 1.0 seconds').ordered
            expect(logger).to receive(:info).with('Running post-start for fake-job/uuid-1 (0)').ordered

            state_applier.apply(update_config)
          end

          it 'updates state on the instance model after agent reports that job is in desired state' do
            allow(agent_client).to receive(:run_script)
            allow(agent_client).to receive(:get_state).and_return({'job_state' => 'running', 'processes' => [{'state' => 'starting', 'name' => 'template'}]}).ordered
            expect {
              state_applier.apply(update_config)
            }.to change(instance.model, :state)
                   .from('stopped')
                   .to('started')
          end
        end

        context 'when trying to stop a job' do
          let(:instance_state) { 'stopped' }
          let(:instance_model_state) { 'started' }

          context 'when job does not stop within max_watch_time' do
            before do
              allow(agent_client).to receive(:get_state).and_return({'job_state' => 'running', 'processes' => [{'state' => 'starting', 'name' => 'template'}]}, {'job_state' => 'running', 'processes' => [{'state' => 'starting', 'name' => 'template'}]})
            end

            it 'raises AgentJobNotStopped' do
              expect(state_applier).to receive(:sleep).with(1.0).twice
              expect(agent_client).to_not receive(:run_script).with('post-start', {})

              expect { state_applier.apply(update_config) }.to raise_error AgentJobNotStopped, "'fake-job/uuid-1 (0)' is still running despite the stop command"
            end

            it 'does not update state on the instance model' do
              expect(instance.model.state).to eq('started')

              expect { state_applier.apply(update_config) }.to raise_error AgentJobNotStopped
              expect(instance.model.state).to eq('started')
            end
          end

          context 'when the job successfully stops' do
            before do
              allow(agent_client).to receive(:get_state).and_return({'job_state' => 'running', 'processes' => [{'state' => 'starting', 'name' => 'template'}]}, {'job_state' => 'stopped', 'processes' => [{'state' => 'failing', 'name' => 'broken_template'}]})
            end

            it 'does not run the post-start script after instance is in desired state' do
              expect(state_applier).to receive(:sleep).with(1.0).twice
              expect(agent_client).to_not receive(:run_script).with('post-start', {})

              state_applier.apply(update_config)
            end
          end
        end
      end
    end
  end
end
