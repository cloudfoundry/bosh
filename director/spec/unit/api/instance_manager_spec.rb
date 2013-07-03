require 'spec_helper'

describe Bosh::Director::Api::InstanceManager do
  let(:instance) { double('Instance', id: 90210) }
  let(:task) { double('Task', id: 42) }
  let(:user) { 'FAKE_USER' }

  before do
    Resque.stub(:enqueue)
    BD::JobQueue.any_instance.stub(create_task: task)
  end

  pending '#find_instance'

  pending '#find_by_name'

  pending '#filter_by'

  pending '#agent_client_for'

  describe '#fetch_logs' do
    let(:deployment_name) { 'FAKE_DEPLOYMENT_NAME' }
    let(:job) { 'FAKE_JOB' }
    let(:index) { 'FAKE_INDEX' }

    before do
      subject.should_receive(:find_by_name).
          with(deployment_name, job, index).
          and_return(instance)
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
    let(:options) do
      {
          'deployment_name' => 'DEPLOYMENT_NAME',
          'command' => 'COMMAND',
          'target' => 'TARGET'
      }
    end

    before do
      BDA::DeploymentManager.any_instance.stub(find_by_name: deployment)
    end

    it 'enqueues a resque job' do
      Resque.should_receive(:enqueue).with(BD::Jobs::Ssh, task.id, deployment.id, options)

      subject.ssh(user, options)
    end

    it 'returns the task created by JobQueue' do
      expect(subject.ssh(user, options)).to eq(task)
    end
  end
end