require 'spec_helper'

module Bosh::Director
  describe Starter do
    let(:agent_client) { instance_double('Bosh::Director::AgentClient') }
    let(:task) { instance_double('Bosh::Director::EventLog::Task') }
    let(:current_job_state) { 'running' }
    let(:update_watch_time) { '1000-2000' }

    let(:update_config) do
      DeploymentPlan::UpdateConfig.new(
        'canaries' => 1,
        'max_in_flight' => 1,
        'canary_watch_time' => '1000-2000',
        'update_watch_time' => update_watch_time,
      )
    end

    let(:instance) do
      instance_double(
        DeploymentPlan::Instance,
        current_job_state: current_job_state,
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

    before do
      allow(instance).to receive(:to_s).and_return('fake-job/uuid-1 (0)')
      allow(per_spec_logger).to receive(:info)
    end

    describe '#start' do
      before do
        allow(task).to receive(:advance).with(10, status: 'executing pre-start')
        allow(agent_client).to receive(:run_script).with('pre-start', {})
        allow(task).to receive(:advance).with(20, status: 'starting jobs')
        allow(agent_client).to receive(:start)
        allow(agent_client).to receive(:get_state).and_return('job_state' => current_job_state)
        allow(task).to receive(:advance)
          .with(10, status: 'executing post-start')
        allow(agent_client).to receive(:run_script).with('post-start', {})
      end

      it 'waits for desired state and runs post-start' do
        Starter.start(
          instance: instance,
          agent_client: agent_client,
          update_config: update_config,
          task: task,
        )

        expect(agent_client).to have_received(:run_script).with('pre-start', {}).ordered
        expect(agent_client).to have_received(:start).ordered
        expect(agent_client).to have_received(:get_state).ordered
        expect(agent_client).to have_received(:run_script).with('post-start', {}).ordered
      end

      it 'logs while waiting until instance is in desired state' do
        Starter.start(
          instance: instance,
          agent_client: agent_client,
          update_config: update_config,
          task: task,
        )

        expect(per_spec_logger).to have_received(:info).with('Running pre-start for fake-job/uuid-1 (0)').ordered
        expect(per_spec_logger).to have_received(:info).with('Starting instance fake-job/uuid-1 (0)').ordered
        expect(per_spec_logger).to have_received(:info).with('Waiting for 1.0 seconds to check fake-job/uuid-1 (0) status').ordered
        expect(per_spec_logger).to have_received(:info).with('Checking if fake-job/uuid-1 (0) has been updated after 1.0 seconds').ordered
        expect(per_spec_logger).to have_received(:info).with('Running post-start for fake-job/uuid-1 (0)').ordered
      end

      context 'when the update config is not defined' do
        it 'waits for desired state and runs post-start' do
          Starter.start(
            instance: instance,
            agent_client: agent_client,
            update_config: nil,
            task: task,
          )

          expect(agent_client).to have_received(:run_script).with('pre-start', {}).ordered
          expect(agent_client).to have_received(:start).ordered
          expect(agent_client).not_to have_received(:get_state).ordered
          expect(agent_client).not_to have_received(:run_script).with('post-start', {}).ordered
        end
      end

      context 'when wait_for_running is false' do
        it 'waits for desired state and does not run post-start' do
          Starter.start(
            instance: instance,
            agent_client: agent_client,
            update_config: update_config,
            wait_for_running: false,
            task: task,
          )

          expect(agent_client).to have_received(:run_script).with('pre-start', {}).ordered
          expect(agent_client).to have_received(:start).ordered
          expect(agent_client).not_to have_received(:get_state)
          expect(agent_client).not_to have_received(:run_script).with('post-start', {})
        end
      end

      context 'when the job fails to start fails' do
        let(:current_job_state) { 'unmonitored' }

        it 'throws an exception' do
          expect do
            Starter.start(
              instance: instance,
              agent_client: agent_client,
              update_config: update_config,
              task: task,
            )
          end.to raise_exception(Bosh::Director::AgentJobNotRunning)
        end
      end

      context 'when the task is cancelled' do
        it 'should stop execution if task was canceled' do
          t = FactoryBot.create(:models_task, id: 42, state: 'cancelling')
          base_job = Jobs::BaseJob.new
          allow(base_job).to receive(:task_id).and_return(t.id)
          allow(Config).to receive(:current_job).and_return(base_job)
          Config.instance_variable_set(:@current_job, base_job)

          expect do
            Starter.start(
              instance: instance,
              agent_client: agent_client,
              update_config: update_config,
              task: task,
            )
          end.to raise_error Bosh::Director::TaskCancelled, 'Task 42 cancelled'
        end
      end

      context 'when the job does not start right away' do
        before do
          allow(agent_client).to receive(:get_state).and_return({ 'job_state' => 'stopped' }, { 'job_state' => 'running' })
        end

        it 'waits for the desired state and runs post start' do
          Starter.start(
            instance: instance,
            agent_client: agent_client,
            update_config: update_config,
            task: task,
          )

          expect(agent_client).to have_received(:run_script).with('pre-start', {}).ordered
          expect(agent_client).to have_received(:start).ordered
          expect(agent_client).to have_received(:get_state).twice.ordered
          expect(agent_client).to have_received(:run_script).with('post-start', {}).ordered
        end
      end
    end
  end
end
