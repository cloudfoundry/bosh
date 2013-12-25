require 'spec_helper'

module Bosh::Director
  describe Api::VmStateManager do
    let(:deployment) { double('Deployment', id: 90210) }
    let(:task) { double('Task') }
    let(:username) { 'username-1' }
    let(:job_queue) { instance_double('Bosh::Director::JobQueue') }

    before do
      JobQueue.stub(:new).and_return(job_queue)
    end

    describe '#fetch_vm_state' do
      it 'enqueues a resque job' do
        Dir.stub(mktmpdir: 'FAKE_TMPDIR')

        job_queue.should_receive(:enqueue).with(
          username, Jobs::VmState, 'retrieve vm-stats', [deployment.id, 'FAKE_FORMAT']).and_return(task)

        expect(subject.fetch_vm_state(username, deployment, 'FAKE_FORMAT')).to eq(task)
      end
    end
  end
end
