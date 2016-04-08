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

        it 'enqueues a background job' do
          instance.update(index: index)

          expect(job_queue).to receive(:enqueue).with(
            username, Jobs::FetchLogs, 'fetch logs', [instance.id, options], deployment_name).and_return(task)

          expect(subject.fetch_logs(username, deployment, job, index, options)).to eq(task)
        end
      end

      context 'when uuid is provided' do
        let(:uuid) { 'fakeId123' }

        it 'enqueues a job' do
          expect(job_queue).to receive(:enqueue).with(
            username, Jobs::FetchLogs, 'fetch logs', [instance.id, options], deployment_name).and_return(task)

          expect(subject.fetch_logs(username, deployment, job, uuid, options)).to eq(task)
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

      it 'enqueues a DJ job' do
        expect(job_queue).to receive(:enqueue).with(
          username, Jobs::Ssh, 'ssh: COMMAND:TARGET', [deployment.id, options]).and_return(task)

        expect(subject.ssh(username, deployment, options)).to eq(task)
      end
    end

    describe '#find_instance' do
      it 'finds instance by id' do
        expect(subject.find_instance(instance.id)).to eq instance
      end
    end

    describe '#find_instances_by_deployment' do
      it 'uses InstanceLookup#by_deployment' do
        deployment = Models::Deployment.make(name: 'given_deployment')

        expect_any_instance_of(Api::InstanceLookup).to receive(:by_deployment).with(deployment)

        subject.find_instances_by_deployment(deployment)
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

        expect(subject.find_by_name(deployment, job, index)).to eq instance
        expect(subject.find_by_name(deployment, job, id)).to eq instance
      end
    end

    describe '#filter_by' do
      it 'filters by given criteria' do
        expect(subject.filter_by(deployment, uuid: instance.uuid)).to eq [instance]
      end
    end

    describe '#fetch_instances_with_vm' do

      before { allow(JobQueue).to receive(:new).and_return(job_queue) }

      it 'enqueues a DJ job' do
        allow(Dir).to receive_messages(mktmpdir: 'FAKE_TMPDIR')

        expect(job_queue).to receive(:enqueue).with(
            username, Jobs::VmState, 'retrieve vm-stats', [deployment.id, 'FAKE_FORMAT'], deployment.name).and_return(task)

        expect(subject.fetch_instances_with_vm(username, deployment, 'FAKE_FORMAT')).to eq(task)
      end
    end

    describe '#fetch_instances' do

      before { allow(JobQueue).to receive(:new).and_return(job_queue) }

      it 'enqueues a DJ job' do
        allow(Dir).to receive_messages(mktmpdir: 'FAKE_TMPDIR')

        expect(job_queue).to receive(:enqueue).with(
            username, Jobs::VmState, 'retrieve vm-stats', [deployment.id, 'FAKE_FORMAT', true], deployment.name).and_return(task)

        expect(subject.fetch_instances(username, deployment, 'FAKE_FORMAT')).to eq(task)
      end
    end
  end
end
