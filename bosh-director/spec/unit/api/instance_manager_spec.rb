require 'spec_helper'

module Bosh::Director
  describe Api::InstanceManager do
    let(:deployment) { Models:: Deployment.make(name: deployment_name) }
    let(:instance) { Models::Instance.make(uuid: 'fakeId123', deployment: deployment, job: job) }
    let(:task) { double('Task') }
    let(:username) { 'FAKE_USER' }
    let(:instance_lookup) { Api::InstanceLookup.new }
    let(:job_queue) { instance_double('Bosh::Director::JobQueue') }
    let(:options) { { foo: 'bar' } }
    let(:deployment_name) { 'FAKE_DEPLOYMENT_NAME' }
    let(:job) { 'FAKE_JOB' }

    before do
      allow(JobQueue).to receive(:new).and_return(job_queue)
    end

    describe '#fetch_logs' do
      context 'when index is provided' do
        let(:index) { '3' }

        it 'enqueues a resque job' do
          instance.update(index: index)

          expect(job_queue).to receive(:enqueue).with(
            username, Jobs::FetchLogs, 'fetch logs', [instance.id, options]).and_return(task)

          expect(subject.fetch_logs(username, deployment_name, job, index, options)).to eq(task)
        end
      end

      context 'when uuid is provided' do
        let(:uuid) { 'fakeId123' }

        it 'enqueues a resque job' do
          expect(job_queue).to receive(:enqueue).with(
            username, Jobs::FetchLogs, 'fetch logs', [instance.id, options]).and_return(task)

          expect(subject.fetch_logs(username, deployment_name, job, uuid, options)).to eq(task)
        end
      end
    end

    describe '#ssh' do
      let(:deployment_lookup) { Api::DeploymentLookup.new }
      let(:options) do
        {
          'deployment_name' => deployment_name,
          'command' => 'COMMAND',
          'target' => 'TARGET'
        }
      end

      it 'enqueues a resque job' do
        expect(job_queue).to receive(:enqueue).with(
          username, Jobs::Ssh, 'ssh: COMMAND:TARGET', [deployment.id, options]).and_return(task)

        expect(subject.ssh(username, options)).to eq(task)
      end
    end

    describe '#find_instance' do
      it 'finds instance by id' do
        expect(subject.find_instance(instance.id)).to eq instance
      end
    end

    describe '#find_by_name' do
      let(:deployment_name) { 'FAKE_DEPLOYMENT_NAME' }
      let(:job) { 'FAKE_JOB' }
      let(:index) { 3 }
      let(:id) { '9A0A5D0E-868A-431C-A6EA-9E8EDF4DBF81' }

      it 'finds instance by deployment name, job name and index or id' do
        instance.update(index: index)
        instance.update(uuid: id)

        expect(subject.find_by_name(deployment_name, job, index)).to eq instance
        expect(subject.find_by_name(deployment_name, job, id)).to eq instance
      end
    end

    describe '#filter_by' do
      it 'filters by given criteria' do
        expect(subject.filter_by(uuid: instance.uuid)).to eq [instance]
      end
    end
  end
end
