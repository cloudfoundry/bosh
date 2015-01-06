require 'spec_helper'

module Bosh::Director
  describe Api::InstanceManager do
    let(:instance) { double('Instance', id: 90210) }
    let(:task) { double('Task') }
    let(:username) { 'FAKE_USER' }
    let(:instance_lookup) { instance_double('Bosh::Director::Api::InstanceLookup') }
    let(:job_queue) { instance_double('Bosh::Director::JobQueue') }
    let(:options) { { foo: 'bar' } }

    before do
      allow(Api::InstanceLookup).to receive_messages(new: instance_lookup)
      allow(JobQueue).to receive(:new).and_return(job_queue)
    end

    describe '#fetch_logs' do
      let(:deployment_name) { 'FAKE_DEPLOYMENT_NAME' }
      let(:job) { 'FAKE_JOB' }
      let(:index) { 'FAKE_INDEX' }

      before do
        allow(instance_lookup).to receive(:by_attributes).with(deployment_name, job, index).and_return(instance)
      end

      it 'enqueues a resque job' do
        expect(job_queue).to receive(:enqueue).with(
          username, Jobs::FetchLogs, 'fetch logs', [instance.id, options]).and_return(task)

        expect(subject.fetch_logs(username, deployment_name, job, index, options)).to eq(task)
      end
    end

    describe '#ssh' do
      let(:deployment) { double('Deployment', id: 8675309) }
      let(:deployment_lookup) { instance_double('Bosh::Director::Api::DeploymentLookup') }
      let(:options) do
        {
          'deployment_name' => 'DEPLOYMENT_NAME',
          'command' => 'COMMAND',
          'target' => 'TARGET'
        }
      end

      before do
        allow(Bosh::Director::Api::DeploymentLookup).to receive_messages(new: deployment_lookup)
        allow(deployment_lookup).to receive_messages(by_name: deployment)
      end

      it 'enqueues a resque job' do
        expect(job_queue).to receive(:enqueue).with(
          username, Jobs::Ssh, 'ssh: COMMAND:TARGET', [deployment.id, options]).and_return(task)

        expect(subject.ssh(username, options)).to eq(task)
      end
    end

    describe '#find_instance' do
      it 'delegates to instance lookup' do
        expect(instance_lookup).to receive(:by_id).with(instance.id).and_return(instance)
        expect(subject.find_instance(instance.id)).to eq instance
      end
    end

    describe '#find_by_name' do
      let(:deployment_name) { 'FAKE_DEPLOYMENT_NAME' }
      let(:job) { 'FAKE_JOB' }
      let(:index) { 'FAKE_INDEX' }

      it 'delegates to instance lookup' do
        expect(instance_lookup).to receive(:by_attributes).with(deployment_name, job, index).and_return(instance)
        expect(subject.find_by_name(deployment_name, job, index)).to eq instance
      end
    end

    describe '#filter_by' do
      it 'delegates to instance lookup' do
        expect(instance_lookup).to receive(:by_filter).with(id: 5).and_return(instance)
        expect(subject.filter_by(id: 5)).to eq instance
      end
    end

  end
end
