require 'spec_helper'

describe Bosh::Director::Api::VmStateManager do
  let(:deployment) { double('Deployment', id: 90210) }
  let(:task) { double('Task', id: 42) }
  let(:user) { 'FAKE_USER' }

  before do
    Resque.stub(:enqueue)
    BD::JobQueue.any_instance.stub(create_task: task)
  end

  describe '#fetch_vm_state' do
    it 'enqueues a resque job' do
      Dir.stub(mktmpdir: 'FAKE_TMPDIR')

      Resque.should_receive(:enqueue).with(BD::Jobs::VmState, task.id, deployment.id, 'FAKE_FORMAT')

      subject.fetch_vm_state(user, deployment, 'FAKE_FORMAT')
    end

    it 'returns the task created by JobQueue' do
      expect(subject.fetch_vm_state(user, deployment, 'FAKE_FORMAT')).to eq(task)
    end
  end
end
