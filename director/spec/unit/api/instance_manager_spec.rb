require 'spec_helper'

describe Bosh::Director::Api::InstanceManager do
  let(:instance) { double('Instance', id: 90210) }
  let(:task) { double('Task', id: 42) }
  let(:user) { 'FAKE_USER' }
  let(:instance_lookup) { instance_double('Bosh::Director::Api::InstanceLookup') }

  before do
    Resque.stub(:enqueue)
    Bosh::Director::Api::InstanceLookup.stub(new: instance_lookup)
    BD::JobQueue.any_instance.stub(create_task: task)
  end

  describe '#fetch_logs' do
    let(:deployment_name) { 'FAKE_DEPLOYMENT_NAME' }
    let(:job) { 'FAKE_JOB' }
    let(:index) { 'FAKE_INDEX' }

    before do
      instance_lookup.stub(:by_attributes).with(deployment_name, job, index).and_return(instance)
    end

    it 'enqueues a resque job' do
      Resque.should_receive(:enqueue).with(BD::Jobs::FetchLogs, task.id, instance.id, {})

      subject.fetch_logs(user, deployment_name, job, index)
    end

    it 'returns the task created by JobQueue' do
      expect(subject.fetch_logs(user, deployment_name, job, index)).to eq(task)
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
      Bosh::Director::Api::DeploymentLookup.stub(new: deployment_lookup)
      deployment_lookup.stub(by_name: deployment)
    end

    it 'enqueues a resque job' do
      Resque.should_receive(:enqueue).with(BD::Jobs::Ssh, task.id, deployment.id, options)

      subject.ssh(user, options)
    end

    it 'returns the task created by JobQueue' do
      expect(subject.ssh(user, options)).to eq(task)
    end
  end

  describe '#find_instance' do
    it 'delegates to instance lookup' do
      instance_lookup.should_receive(:by_id).with(instance.id).and_return(instance)
      expect(subject.find_instance(instance.id)).to eq instance
    end
  end

  describe '#find_by_name' do
    let(:deployment_name) { 'FAKE_DEPLOYMENT_NAME' }
    let(:job) { 'FAKE_JOB' }
    let(:index) { 'FAKE_INDEX' }

    it 'delegates to instance lookup' do
      instance_lookup.should_receive(:by_attributes).with(deployment_name, job, index).and_return(instance)
      expect(subject.find_by_name(deployment_name, job, index)).to eq instance
    end
  end

  describe '#filter_by' do
    it 'delegates to instance lookup' do
      instance_lookup.should_receive(:by_filter).with(id: 5).and_return(instance)
      expect(subject.filter_by(id: 5)).to eq instance
    end
  end

end