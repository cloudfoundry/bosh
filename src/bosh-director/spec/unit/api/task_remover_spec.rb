require 'spec_helper'
require 'fakefs/spec_helpers'
require 'bosh/director/api/task_remover'

module Bosh::Director::Api
  describe TaskRemover do
    include FakeFS::SpecHelpers

    def make_n_tasks(num_tasks, type = default_type)
      num_tasks.times do |i|
        task = Bosh::Director::Models::Task.make(state: 'done', output: "/director/tasks/#{type}_#{i}", type: type)
        FileUtils.mkpath(task.output)
      end
    end

    subject(:remover) { TaskRemover.new(3) }
    let(:default_type) { 'type' }
    let(:second_type) { 'type1' }

    def tasks
      Bosh::Director::Models::Task.order { Sequel.asc(:id) }.all
    end

    describe '#remove' do
      context 'when there are fewer than max_tasks task of the given type in the database' do
        before do
          make_n_tasks(1, second_type)
          make_n_tasks(2)
        end

        it 'it does not remove anything' do
          expect(remover).to_not receive(:remove_task)

          remover.remove(default_type)
        end
      end

      context 'when there are =max_tasks of the given type in the database' do
        before do
          make_n_tasks(1, second_type)
          make_n_tasks(3)
        end

        it 'it does not remove anything' do
          expect(remover).to_not receive(:remove_task)

          remover.remove(default_type)
        end
      end

      context 'when there is one more than max_tasks tasks of the given type in the database' do
        before do
          make_n_tasks(1, second_type)
          make_n_tasks(4)
        end

        it 'removes the first created one of the given type' do
          expect(remover).to receive(:remove_task).with(tasks[1])

          remover.remove(default_type)
        end
      end

      context 'when there are 2 more than max_tasks task of the given type in the database' do
        before do
          make_n_tasks(1, second_type)
          make_n_tasks(5)
        end

        it 'removes the first two created tasks of the given type' do
          expect(remover).to receive(:remove_task).with(tasks[1])
          expect(remover).to receive(:remove_task).with(tasks[2])

          remover.remove(default_type)
        end
      end

      context 'when there are 10 more than max_tasks task of the given type in the database' do
        before do
          make_n_tasks(1, second_type)
          make_n_tasks(13)
        end

        it 'removes 10 tasks older than the latest max_tasks of the given type' do
          10.downto(1).each do |index|
            expect(remover).to receive(:remove_task).with(tasks[index])
          end

          remover.remove(default_type)
        end
      end

      context 'when there are 2 types with more than max_tasks tasks in the database' do
        before do
          make_n_tasks(4, second_type)
          make_n_tasks(4)
        end

        it 'keeps the tasks which have a different type' do
          (0..3).each do |index|
            expect(remover).to_not receive(:remove_task).with(tasks[index])
          end

          remover.remove(default_type)
        end
      end

      context 'when specific states should be ignored from removal' do
        before do
          make_n_tasks(1, second_type)
          make_n_tasks(5)
          running_task = tasks[1]
          running_task.update(state: state)
        end

        context 'state is processing' do
          let(:state) { :processing }

          it 'removes task older than the latest max_tasks that do not correspond to a task that is in a processing state' do
            expect(remover).to receive(:remove_task).with(tasks[2])

            remover.remove(default_type)
          end
        end

        context 'state is queued' do
          let(:state) { :queued }

          it 'removes task older than the latest max_tasks that do not correspond to a task that is in a queued state' do
            expect(remover).to receive(:remove_task).with(tasks[2])

            remover.remove(default_type)
          end
        end
      end

      context 'when task output is nil' do
        subject(:remover) { described_class.new(0) }

        before do
          Bosh::Director::Models::Task.make(state: 'done', output: nil)
          FakeFS.deactivate!
        end

        after { FakeFS.activate! }

        it 'does not fail' do
          expect do
            remover.remove(default_type)
          end.to_not raise_error
        end
      end

      context 'when a task has teams' do
        before do
          make_n_tasks(4)
          team = Bosh::Director::Models::Team.make(name: 'ateam')
          task = Bosh::Director::Models::Task.first
          task.add_team(team)
        end

        it 'is removed' do
          expect(Bosh::Director::Models::Task.first.teams.first.name).to eq('ateam')
          expect do
            remover.remove(default_type)
          end.to change {
            Bosh::Director::Models::Task.count
          }.from(4).to(3)
        end
      end
    end

    describe '#remove_task' do
      before { make_n_tasks(2) }
      let(:first_task) { Bosh::Director::Models::Task.first }

      it 'removes task from data base' do
        first_task = Bosh::Director::Models::Task.first
        expect { remover.remove_task(first_task) }
          .to change { Bosh::Director::Models::Task[first_task.id] }.from(first_task).to(nil)

        expect(Bosh::Director::Models::Task.last).to_not be_nil
      end

      it 'removes files belonging to task' do
        expect { remover.remove_task(first_task) }
          .to change { Dir["/director/tasks/#{default_type}_*"].count }.from(2).to(1)

        expect(Dir['/director/tasks/type_1']).to_not be_nil
      end

      it 'does not fail when called multiple times on the same task, writes a debug log' do
        expect(Bosh::Director::Config).to receive(:logger)
          .and_return(double(Logging::Logger, debug: nil))
        expect do
          remover.remove_task(first_task)
          remover.remove_task(first_task)
        end.to_not raise_error
      end
    end
  end
end
