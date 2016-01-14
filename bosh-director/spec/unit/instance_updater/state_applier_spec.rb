require 'spec_helper'

module Bosh::Director
  describe InstanceUpdater::StateApplier do
    include Support::StemcellHelpers

    subject(:state_applier) { InstanceUpdater::StateApplier.new(instance_plan, agent_client, rendered_job_templates_cleaner, logger) }

    let(:instance_plan) do
      DeploymentPlan::InstancePlan.new({
          existing_instance: instance_model,
          desired_instance: DeploymentPlan::DesiredInstance.new(job),
          instance: instance,
          network_plans: [],
        })
    end
    let(:job) do
      job = instance_double('Bosh::Director::DeploymentPlan::Job',
        name: 'fake-job',
        spec: {'name' => 'job'},
        canonical_name: 'job',
        instances: ['instance0'],
        default_network: {},
        vm_type: DeploymentPlan::VmType.new({'name' => 'fake-vm-type'}),
        stemcell: make_stemcell({:name => 'fake-stemcell-name', :version => '1.0'}),
        env: DeploymentPlan::Env.new({'key' => 'value'}),
        package_spec: {},
        persistent_disk_type: nil,
        can_run_as_errand?: false,
        link_spec: 'fake-link',
        compilation?: false,
        templates: [],
        properties: {})
    end
    let(:plan) do
      instance_double('Bosh::Director::DeploymentPlan::Planner', {
          name: 'fake-deployment',
          model: deployment,
        })
    end
    let(:deployment) { Bosh::Director::Models::Deployment.make(name: 'fake-deployment') }
    let(:instance) { DeploymentPlan::Instance.create_from_job(job, 0, instance_state, plan, {}, nil, logger) }
    let(:instance_model) { Models::Instance.make(state: instance_model_state, uuid: 'uuid-1') }
    let(:blobstore) { instance_double(Bosh::Blobstore::Client) }
    let(:agent_client) { instance_double(AgentClient) }
    let(:rendered_job_templates_cleaner) { instance_double(RenderedJobTemplatesCleaner) }
    let(:instance_state) { 'started' }
    let(:instance_model_state) { 'stopped' }

    before { instance.bind_existing_instance_model(instance_model) }

    describe 'applying state' do
      before do
        allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).with(instance_model.credentials, instance_model.agent_id).and_return(agent_client)
        allow(agent_client).to receive(:apply)
        allow(agent_client).to receive(:run_script)
        allow(agent_client).to receive(:start)
        allow(rendered_job_templates_cleaner).to receive(:clean)
      end

      it 'runs the pre-start and start scripts in order' do
        expect(agent_client).to receive(:run_script).with('pre-start', {}).ordered
        expect(agent_client).to receive(:start).ordered

        state_applier.apply
      end

      it 'updates instance spec' do
        expect(agent_client).to receive(:apply).with(instance_plan.spec.as_apply_spec)
        state_applier.apply
        expect(instance_model.spec).to eq(instance_plan.spec.full_spec)
      end

      it 'cleans rendered templates after applying' do
        expect(agent_client).to receive(:apply).ordered
        expect(rendered_job_templates_cleaner).to receive(:clean).ordered
        state_applier.apply
      end

      context 'when instance state is stopped' do
        let(:instance_state) { 'stopped' }

        it 'does not run the start script' do
          expect(agent_client).to_not receive(:run_script)
          expect(agent_client).to_not receive(:start)
          state_applier.apply
        end
      end
    end

    describe 'post_start' do
      before do
        allow(state_applier).to receive(:sleep)
      end

      context 'scheduling' do
        before do
          allow(agent_client).to receive(:get_state).and_return({'job_state' => 'stopped'})
        end

        it 'divides the range into 10 equal steps' do
          expect(state_applier).to receive(:sleep).with(10.0).exactly(9).times
          expect { state_applier.post_start(1000, 91_000) }.to raise_error
        end

        context 'when the interval length is less than 10 seconds' do
          it 'divides the interval into 1 second steps' do
            expect(state_applier).to receive(:sleep).with(1.0).exactly(8).times
            expect { state_applier.post_start(1000, 8_000) }.to raise_error
          end
        end
      end

      context 'when trying to start a job' do
        context 'when job does not start within max_watch_time' do
          before do
            allow(agent_client).to receive(:get_state).and_return({'job_state' => 'stopped'}, {'job_state' => 'stopped'})
          end

          it 'raises AgentJobNotRunning' do
            expect(state_applier).to receive(:sleep).with(1.0).twice
            expect(agent_client).to_not receive(:run_script).with('post-start', {})

            expect { state_applier.post_start(1000, 2000) }.to raise_error AgentJobNotRunning, "`fake-job/0 (uuid-1)' is not running after update"
          end

          it 'does not update state on the instance model' do
            expect(instance.model.state).to eq('stopped')

            expect { state_applier.post_start(1000, 2000) }.to raise_error AgentJobNotRunning
            expect(instance.model.state).to eq('stopped')
          end
        end

        context 'when the job successfully starts' do
          before do
            allow(agent_client).to receive(:get_state).and_return({'job_state' => 'stopped'}, {'job_state' => 'running'})
            allow(state_applier).to receive(:sleep)
            allow(agent_client).to receive(:run_script)
          end

          it 'runs the post-start script after instance is in desired state' do
            expect(state_applier).to receive(:sleep).with(1.0).twice
            expect(agent_client).to receive(:run_script).with('post-start', {})

            state_applier.post_start(1000, 2000)
          end

          it 'logs while waiting until instance is in desired state' do
            expect(logger).to receive(:info).with('Waiting for 1.0 seconds to check fake-job/0 (uuid-1) status').ordered
            expect(logger).to receive(:info).with('Checking if fake-job/0 (uuid-1) has been updated after 1.0 seconds').ordered
            expect(logger).to receive(:info).with('Waiting for 1.0 seconds to check fake-job/0 (uuid-1) status').ordered
            expect(logger).to receive(:info).with('Checking if fake-job/0 (uuid-1) has been updated after 1.0 seconds').ordered

            state_applier.post_start(1000, 2000)
          end

          it 'updates state on the instance model after agent reports that job is in desired state' do
            allow(agent_client).to receive(:run_script)
            allow(agent_client).to receive(:get_state).and_return({'job_state' => 'running'}).ordered
            expect {
              state_applier.post_start(1000, 8_000)
            }.to change(instance.model, :state)
                   .from('stopped')
                   .to('started')
          end
        end
      end

      context 'when trying to stop a job' do
        let(:instance_state) { 'stopped' }
        let(:instance_model_state) { 'started' }

        context 'when job does not stop within max_watch_time' do
          before do
            allow(agent_client).to receive(:get_state).and_return({'job_state' => 'running'}, {'job_state' => 'running'})
          end

          it 'raises AgentJobNotStopped' do
            expect(state_applier).to receive(:sleep).with(1.0).twice
            expect(agent_client).to_not receive(:run_script).with('post-start', {})

            expect { state_applier.post_start(1000, 2000) }.to raise_error AgentJobNotStopped, "`fake-job/0 (uuid-1)' is still running despite the stop command"
          end

          it 'does not update state on the instance model' do
            expect(instance.model.state).to eq('started')

            expect { state_applier.post_start(1000, 2000) }.to raise_error AgentJobNotStopped
            expect(instance.model.state).to eq('started')
          end
        end

        context 'when the job successfully stops' do
          before do
            allow(agent_client).to receive(:get_state).and_return({'job_state' => 'running'}, {'job_state' => 'stopped'})
          end

          it 'does not run the post-start script after instance is in desired state' do
            expect(state_applier).to receive(:sleep).with(1.0).twice
            expect(agent_client).to_not receive(:run_script).with('post-start', {})

            state_applier.post_start(1000, 2000)
          end
        end
      end
    end
  end
end
