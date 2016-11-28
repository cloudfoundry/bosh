require 'spec_helper'

module Bosh::Cli::TaskTracking
  describe StageCollection do
    subject(:stage_collection) { described_class.new(callbacks) }
    let(:callbacks) { {} }

    describe '#update_with_event' do
      context 'when the stage and tags do not match any existing stages' do
        before { stage_collection.update_with_event('stage' => 'fake-stage1', 'tags' => ['tag1']) }
        event = { 'stage' => 'fake-stage2', 'tags' => ['tag2'], 'total' => 0 }

        it 'adds a new stage' do
          expect {
            stage_collection.update_with_event(event)
          }.to change { stage_collection.stages.size }.from(1).to(2)
        end

        it 'sends the event to the new stage' do
          new_stage = instance_double('Bosh::Cli::TaskTracking::Stage', name: 'fake-stage2', tags: ['tag2'])
          allow(Stage).to receive(:new).with('fake-stage2', ['tag2'], 0, callbacks).and_return(new_stage)

          expect(new_stage).to receive(:update_with_event).with(event)
          stage_collection.update_with_event(event)
        end
      end

      context 'when the stage matches and tags do not match any existing stages' do
        before { stage_collection.update_with_event('stage' => 'fake-stage', 'tags' => ['tag1']) }
        event = { 'stage' => 'fake-stage', 'tags' => ['tag2'] }

        it 'adds a new stage' do
          expect {
            stage_collection.update_with_event(event)
          }.to change { stage_collection.stages.size }.from(1).to(2)
        end
      end

      context 'when the stage does not match and tags match an existing stage' do
        before { stage_collection.update_with_event('stage' => 'fake-stage1', 'tags' => ['tag']) }
        event = { 'stage' => 'fake-stage2', 'tags' => ['tag'] }

        it 'adds a new stage' do
          expect {
            stage_collection.update_with_event(event)
          }.to change { stage_collection.stages.size }.from(1).to(2)
        end
      end

      context 'when the stage and tags match an existing stage' do
        event = { 'stage' => 'fake-stage', 'tags' => ['tag'] }
        let!(:existing_stage) { stage_collection.update_with_event(event) }

        it 'does not add new stage since there is already a matching stage' do
          expect {
            stage_collection.update_with_event(event)
          }.to_not change { stage_collection.stages.size }.from(1)
        end

        it 'updates existing stage with an event to track tasks and other progress' do
          expect(existing_stage).to receive(:update_with_event).with(event)
          stage_collection.update_with_event(event)
        end
      end
    end
  end

  describe Stage do
    subject(:stage) { described_class.new('fake-stage', ['fake-tag'], 0, callbacks) }
    let(:callbacks) { {} }

    describe '#initialize' do
      it 'sets tags to given tags' do
        expect(described_class.new('fake-stage', ['tag1'], 0, {}).tags).to eq(['tag1'])
      end

      it 'sets tags to be an array when given tags are nil' do
        expect(described_class.new('fake-stage', nil, 0, {}).tags).to eq([])
      end
    end

    describe '#update_with_event' do
      context 'when task name does not match any existing tasks in the stage' do
        before { stage.update_with_event('task' => 'fake-task1') }
        event = { 'task' => 'fake-task2', 'index' => 2, 'progress' => 'fake-progress' }

        it 'adds a new task' do
          expect {
            stage.update_with_event(event)
          }.to change { stage.tasks.size }.from(1).to(2)
        end

        it 'sends the event to the new task' do
          new_task = instance_double('Bosh::Cli::TaskTracking::Task', name: 'fake-task2')
          allow(Task).to receive(:new).with(stage, 'fake-task2', 2, 'fake-progress', callbacks).and_return(new_task)

          expect(new_task).to receive(:update_with_event).with(event)
          stage.update_with_event(event)
        end
      end

      context 'when the task name matches an existing task' do
        event = { 'task' => 'fake-task' }
        let!(:existing_task) { stage.update_with_event(event) }

        it 'does not add new task since there is already a matching task' do
          expect {
            stage.update_with_event(event)
          }.to_not change { stage.tasks.size }.from(1)
        end

        it 'updates existing task with an event to track progress' do
          expect(existing_task).to receive(:update_with_event).with(event)
          stage.update_with_event(event)
        end
      end

      describe 'when the started event for the first task is received' do
        it 'calls stage_started callbacks' do
          callbacks[:stage_started] = -> {}
          expect(callbacks[:stage_started]).to receive(:call).with(stage).once
          stage.update_with_event('stage' => 'fake-stage', 'task' => 'fake-task', 'index' => 1, 'state' => 'started')
          stage.update_with_event('stage' => 'fake-stage', 'task' => 'fake-task', 'index' => 2, 'state' => 'started')
        end
      end

      shared_examples 'an incomplete stage' do
        it 'does not call the finished callback' do
          expect(callbacks[:stage_finished]).not_to receive(:call).with(stage)
          stage.update_with_event(event)
        end

        it 'does not call the failed callback' do
          expect(callbacks[:stage_failed]).not_to receive(:call).with(stage)
          stage.update_with_event(event)
        end
      end

      shared_examples 'a successful stage' do
        it 'calls the finished callback' do
          expect(callbacks[:stage_finished]).to receive(:call).with(stage)
          stage.update_with_event(event)
        end

        it 'does not call the failed callback' do
          expect(callbacks[:stage_failed]).not_to receive(:call).with(stage)
          stage.update_with_event(event)
        end
      end

      shared_examples 'a failed stage' do
        it 'calls the failed callback' do
          expect(callbacks[:stage_failed]).to receive(:call).with(stage)
          stage.update_with_event(event)
        end

        it 'does not call the finished callback' do
          expect(callbacks[:stage_finished]).not_to receive(:call).with(stage)
          stage.update_with_event(event)
        end
      end

      describe 'when a finished event is received' do
        before do
          callbacks[:stage_failed] = instance_double('Proc', call: nil)
          callbacks[:stage_finished] = instance_double('Proc', call: nil)
        end

        let(:index) { 1 }
        let(:total) { index }
        let(:event) do
          {
            'stage' => 'fake-stage',
            'task' => 'fake-task',
            'index' => index,
            'total' => total,
            'state' => 'finished'
          }
        end

        context 'when no other tasks have been seen' do
          context 'when we have seen all the tasks we expect' do
            let(:total) { index }

            it_behaves_like 'a successful stage'
          end

          context 'when we have not seen all the tasks we expect' do
            let(:total) { index + 1 }

            it_behaves_like 'an incomplete stage'
          end

          context 'when we do not know how many tasks to expect' do
            let(:total) { nil }

            it_behaves_like 'a successful stage'
          end
        end

        context 'when all other tasks are finished' do
          let(:index) { 2 }

          before do
            stage.update_with_event(
              'stage' => 'fake-stage',
              'task' => 'fake-task-1',
              'index' => 1,
              'total' => total,
              'state' => 'finished'
            )
          end

          it_behaves_like 'a successful stage'
        end

        context 'when another task is running' do
          let(:index) { 2 }

          before do
            stage.update_with_event(
              'stage' => 'fake-stage',
              'task' => 'fake-task-1',
              'index' => 1,
              'total' => total,
              'state' => 'started'
            )
          end

          it_behaves_like 'an incomplete stage'
        end

        context 'when another task is failed' do
          let(:index) { 2 }

          before do
            stage.update_with_event(
              'stage' => 'fake-stage',
              'task' => 'fake-task-1',
              'index' => 1,
              'total' => total,
              'state' => 'failed'
            )
          end

          it_behaves_like 'a failed stage'
        end
      end

      describe 'when a failed event is received' do
        before do
          callbacks[:stage_failed] = instance_double('Proc', call: nil)
          callbacks[:stage_finished] = instance_double('Proc', call: nil)
        end

        let(:index) { 1 }
        let(:total) { index }
        let(:event) do
          {
            'stage' => 'fake-stage',
            'task' => 'fake-task',
            'index' => index,
            'total' => total,
            'state' => 'failed'
          }
        end

        context 'when no other tasks have been seen' do
          context 'when we have seen all the tasks we expect' do
            let(:total) { index }

            it_behaves_like 'a failed stage'
          end

          context 'when we have not seen all the tasks we expect' do
            let(:total) { index + 1 }

            it_behaves_like 'an incomplete stage'
          end

          context 'when we do not know how many tasks to expect' do
            let(:total) { nil }

            it_behaves_like 'a failed stage'
          end
        end

        context 'when all other tasks are done' do
          let(:index) { 3 }

          before do
            stage.update_with_event(
              'stage' => 'fake-stage',
              'task' => 'fake-task-1',
              'index' => 1,
              'total' => total,
              'state' => 'finished'
            )
            stage.update_with_event(
              'stage' => 'fake-stage',
              'task' => 'fake-task-2',
              'index' => 2,
              'total' => total,
              'state' => 'failed'
            )
          end

          it_behaves_like 'a failed stage'
        end

        context 'when another task is running' do
          let(:index) { 2 }

          before do
            stage.update_with_event(
              'stage' => 'fake-stage',
              'task' => 'fake-task-1',
              'index' => 1,
              'total' => total,
              'state' => 'started'
            )
          end

          it_behaves_like 'an incomplete stage'
        end
      end
    end

    describe '#duration' do
      context 'when all tasks is not finished' do

        it 'sums the durations of all tasks' do
          stage.update_with_event('stage' => 'fake-stage', 'task' => 'fake-task1', 'state' => 'started', 'index' => 1, 'time' => 100)
          stage.update_with_event('stage' => 'fake-stage', 'task' => 'fake-task1', 'state' => 'finished', 'index' => 1, 'time' => 39560)

          stage.update_with_event('stage' => 'fake-stage', 'task' => 'fake-task2', 'state' => 'started', 'index' => 2, 'time' => 200)
          stage.update_with_event('stage' => 'fake-stage', 'task' => 'fake-task2', 'state' => 'finished', 'index' => 2, 'time' => 39660)

          stage.update_with_event('stage' => 'fake-stage', 'task' => 'fake-task3', 'state' => 'started', 'index' => 3, 'time' => 300)
          stage.update_with_event('stage' => 'fake-stage', 'task' => 'fake-task3', 'state' => 'finished', 'index' => 3, 'time' => 39760)

          expect(stage.duration).to eq(39660)
        end
      end

      context 'when one of the tasks is not finished' do
        it 'returns nil' do
          stage.update_with_event('stage' => 'fake-stage', 'task' => 'fake-task1', 'state' => 'started', 'index' => 1, 'time' => 100)
          stage.update_with_event('stage' => 'fake-stage', 'task' => 'fake-task1', 'state' => 'finished', 'index' => 2, 'time' => 39560)

          stage.update_with_event('stage' => 'fake-stage', 'task' => 'fake-task2', 'state' => 'started', 'index' => 2, 'time' => 200)
          stage.update_with_event('stage' => 'fake-stage', 'task' => 'fake-task2', 'state' => 'finished', 'index' => 3, 'time' => 39660)

          stage.update_with_event('stage' => 'fake-stage', 'task' => 'fake-task3', 'state' => 'started', 'index' => 3, 'time' => 300)

          expect(stage.duration).to be(nil)
        end
      end

    end
  end

  describe Task do
    subject(:task) { described_class.new(stage, 'fake-task', 0, 0, callbacks) }
    let(:stage) { Stage.new('fake-stage', ['fake-tag'], 0, {}) }
    let(:callbacks) { {} }

    describe '#update_with_event' do
      it 'updates state to given state' do
        expect {
          task.update_with_event('state' => 'fake-new-state')
        }.to change { task.state }.from(nil).to('fake-new-state')
      end

      it 'updates progress to given progress' do
        expect {
          task.update_with_event('progress' => 'fake-new-progress')
        }.to change { task.progress }.from(0).to('fake-new-progress')
      end

      it 'updates duration when finish before starting' do
        task.update_with_event('state' => 'finished', 'time' => 500)
        expect(task.duration).to be(nil)

        task.update_with_event('state' => 'started', 'time' => 100)
        expect(task.duration).to eq(400)
      end

      it 'updates duration with start before finish' do
        task.update_with_event('state' => 'started', 'time' => 200)
        task.update_with_event('state' => 'finished', 'time' => 500)
        expect(task.duration).to eq(300)
      end

      it 'only uses the first start time when multiple starts are passed' do
        task.update_with_event('state' => 'started', 'time' => 100)
        task.update_with_event('state' => 'started', 'time' => 200)
        task.update_with_event('state' => 'started', 'time' => 300)
        task.update_with_event('state' => 'finished', 'time' => 600)

        expect(task.duration).to eq(500)
      end

      it 'gets duration of nil when job does not finish' do
        task.update_with_event('state' => 'started', 'time' => 100)
        expect(task.duration).to be(nil)
      end

      it 'gets duration of nil when job finishes but was never started' do
        task.update_with_event('state' => 'finished', 'time' => 100)
        expect(task.duration).to be(nil)
      end

      context 'when the task is started' do
        it 'calls task_start callback' do
          callbacks[:task_started] = -> {}
          expect(callbacks[:task_started]).to receive(:call).with(task)
          task.update_with_event('state' => 'started')
        end
      end

      context 'when the task is finished' do
        it 'calls task_finish callback' do
          callbacks[:task_finished] = -> {}
          expect(callbacks[:task_finished]).to receive(:call).with(task)
          task.update_with_event('state' => 'finished')
        end
      end

      context 'when the task is failed' do
        it 'calls task_failed callback' do
          callbacks[:task_failed] = -> {}
          expect(callbacks[:task_failed]).to receive(:call).with(task)
          task.update_with_event('state' => 'failed')
        end
      end

      context 'when data is nil' do
        before { task.update_with_event('data' => nil) }

        describe '#error' do
          subject { super().error }
          it { is_expected.to be(nil) }
        end
      end

      context 'when data is not nil' do
        context 'when there is no error inside data' do
          before { task.update_with_event('data' => {}) }

          describe '#error' do
            subject { super().error }
            it { is_expected.to be(nil) }
          end
        end

        context 'when there is error inside data' do
          before { task.update_with_event('data' => { 'error' => 'fake-error' }) }

          describe '#error' do
            subject { super().error }
            it { is_expected.to eq('fake-error') }
          end
        end
      end
    end

    describe '#done?' do
      context 'when state is finished' do
        before { task.update_with_event('state' => 'finished') }

        it 'is true' do
          expect(task).to be_done
        end
      end

      context 'when state is failed' do
        before { task.update_with_event('state' => 'failed') }

        it 'is true' do
          expect(task).to be_done
        end
      end

      context 'when state is not finished' do
        before { task.update_with_event('state' => 'literally-anything-else') }

        it 'is true' do
          expect(task).not_to be_done
        end
      end
    end

    describe '#failed?' do
      context 'when state is failed' do
        before { task.update_with_event('state' => 'failed') }

        it 'is true' do
          expect(task).to be_failed
        end
      end

      context 'when state is not failed' do
        before { task.update_with_event('state' => 'literally-anything-else') }

        it 'is true' do
          expect(task).not_to be_failed
        end
      end
    end

    describe '#finished?' do
      context 'when state is finished' do
        before { task.update_with_event('state' => 'finished') }

        it 'is true' do
          expect(task).to be_finished
        end
      end

      context 'when state is not finished' do
        before { task.update_with_event('state' => 'literally-anything-else') }

        it 'is true' do
          expect(task).not_to be_finished
        end
      end
    end

    describe 'equality' do
      it 'is not equal when type is not a task' do
        expect(task).to_not eq('not a task')
      end

      it 'is equal if stage, name, and index match' do
        task = Task.new(stage, 'task-name', 0, 0, {})
        same_task = Task.new(stage, 'task-name', 0, 0, {})

        expect(task).to eq(same_task)
      end

      it 'is not equal if stages differ' do
        other_stage = Stage.new('other-stage', ['fake-tag'], 0, {})
        task = Task.new(stage, 'task-name', 0, 0, {})
        other_task = Task.new(other_stage, 'task-name', 0, 0, {})

        expect(task).to_not eq(other_task)
      end

      it 'is not equal if name differs' do
        task = Task.new(stage, 'task-name-1', 0, 0, {})
        same_task = Task.new(stage, 'task-name-2', 0, 0, {})

        expect(task).to_not eq(same_task)
      end

      it 'is not equal if index differs' do
        task = Task.new(stage, 'task-name', 0, 0, {})
        same_task = Task.new(stage, 'task-name', 1, 0, {})

        expect(task).to_not eq(same_task)
      end
    end
  end
end
