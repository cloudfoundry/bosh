shared_examples_for 'raising an error when a task has timed out or been canceled' do
  before { allow(Bosh::Director::Api::TaskManager).to receive(:new).and_return(task_manager) }
  let(:task_manager) { instance_double('Bosh::Director::Api::TaskManager', find_task: task) }
  let(:task) { instance_double('Bosh::Director::Models::Task', id: 42) }

  before { job.task_id = 'some-task' }

  context 'when there is no task_id' do
    before { job.task_id = nil }

    it 'does not raise an error' do
      expect { subject }.not_to raise_error
    end
  end

  context 'when there is no task' do
    before { allow(task_manager).to receive(:find_task).and_return(nil) }

    it 'does not raise an error' do
      expect { subject }.not_to raise_error
    end
  end

  context 'task has been canceled' do
    before { allow(task).to receive(:state).and_return('cancelling') }

    it 'raises TaskCancelled' do
      expect { subject }.to raise_error(Bosh::Director::TaskCancelled)
    end
  end

  context 'task has timed out' do
    before { allow(task).to receive(:state).and_return('timeout') }

    it 'raises TaskCancelled' do
      expect { subject }.to raise_error(Bosh::Director::TaskCancelled)
    end
  end

  context 'task has not been canceled or timed out' do
    before { allow(task).to receive(:state).and_return('anything-else-at-all') }

    it 'does not raise an error' do
      expect { subject }.not_to raise_error
    end
  end
end
