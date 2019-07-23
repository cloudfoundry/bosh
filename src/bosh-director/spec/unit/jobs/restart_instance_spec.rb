require 'spec_helper'

module Bosh::Director
  describe Jobs::RestartInstance do
    include Support::FakeLocks

    let(:manifest) { Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups }
    let(:deployment) { Models::Deployment.make(name: 'simple', manifest: YAML.dump(manifest)) }

    let(:stop_instance_job) { instance_double(Jobs::StopInstance, perform_without_lock: instance_model.name) }
    let(:start_instance_job) { instance_double(Jobs::StartInstance, perform_without_lock: instance_model.name) }

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
        result_msg = job.perform

        expect(Jobs::StopInstance).to have_received(:new).with(deployment.name, instance_model.id, {})
        expect(stop_instance_job).to have_received(:perform_without_lock)
        expect(Jobs::StartInstance).to have_received(:new).with(deployment.name, instance_model.id, {})
        expect(start_instance_job).to have_received(:perform_without_lock)
        expect(result_msg).to eq 'foobar/test-uuid'
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
    end
  end
end
