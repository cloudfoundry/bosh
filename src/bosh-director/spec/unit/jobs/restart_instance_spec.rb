require 'spec_helper'

module Bosh::Director
  describe Jobs::RestartInstance do
    include Support::FakeLocks

    let(:manifest) { Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups }
    let(:deployment) { Models::Deployment.make(name: 'simple', manifest: YAML.dump(manifest)) }
    let(:task_writer) { TaskDBWriter.new(:event_output, task.id) }
    let(:event_log) { EventLog::Log.new(task_writer) }
    let(:event_log_stage) { instance_double('Bosh::Director::EventLog::Stage') }

    let(:stop_instance_job) { instance_double(Jobs::StopInstance, perform_without_lock: nil) }
    let(:start_instance_job) { instance_double(Jobs::StartInstance, perform_without_lock: nil) }

    let(:instance_model) do
      Models::Instance.make(
        deployment: deployment,
        job: 'foobar',
        uuid: 'test-uuid',
        index: '1',
        state: 'started',
      )
    end

    before do
      fake_locks

      allow(Config).to receive(:event_log).and_call_original
      allow(Config.event_log).to receive(:begin_stage).and_return(event_log_stage)
      allow(event_log_stage).to receive(:advance_and_track).and_yield

      allow(Jobs::StopInstance).to receive(:new).and_return(stop_instance_job)
      allow(Jobs::StartInstance).to receive(:new).and_return(start_instance_job)
    end

    describe 'DelayedJob job class expectations' do
      let(:job_type) { :restart_instance }
      let(:queue) { :normal }
      it_behaves_like 'a DJ job'
    end

    describe 'perform' do
      it 'should restart the instance' do
        job = Jobs::RestartInstance.new(deployment.name, instance_model.id, {})
        job.perform

        expect(Jobs::StopInstance).to have_received(:new).with(deployment.name, instance_model.id, {})
        expect(stop_instance_job).to have_received(:perform_without_lock)
        expect(Jobs::StartInstance).to have_received(:new).with(deployment.name, instance_model.id, {})
        expect(start_instance_job).to have_received(:perform_without_lock)
      end

      it 'respects skip_drain option' do
        job = Jobs::RestartInstance.new(deployment.name, instance_model.id, skip_drain: true)
        job.perform

        expect(Jobs::StopInstance).to have_received(:new).with(deployment.name, instance_model.id, skip_drain: true)
        expect(stop_instance_job).to have_received(:perform_without_lock)
        expect(Jobs::StartInstance).to have_received(:new).with(deployment.name, instance_model.id, an_instance_of(Hash))
        expect(start_instance_job).to have_received(:perform_without_lock)
      end

      it 'obtains a deployment lock' do
        job = Jobs::RestartInstance.new(deployment.name, instance_model.id, {})
        expect(job).to receive(:with_deployment_lock).with('simple').and_yield
        job.perform
      end

      it 'logs restarting' do
        expect(Config.event_log).to receive(:begin_stage).with('Restarting instance foobar').and_return(event_log_stage)
        expect(event_log_stage).to receive(:advance_and_track).with('foobar/test-uuid (1)').and_yield
        job = Jobs::RestartInstance.new(deployment.name, instance_model.id, {})
        job.perform
      end
    end
  end
end
