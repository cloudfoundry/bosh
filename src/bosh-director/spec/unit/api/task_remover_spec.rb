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

    subject(:remover) { described_class.new(3) }
    let(:default_type) { 'type' }
    let(:second_type) { 'type1' }

    describe '#remove' do
      context 'when there are fewer than max_tasks task of the given type in the database' do
        before {
          make_n_tasks(1, second_type)
          make_n_tasks(2)
        }

        it 'it does not remove anything' do
          expect(remover).to_not receive(:remove_task)

          remover.remove(default_type)
        end
      end

      context 'when there are exactly max_tasks of the given type in the database' do
        before {
          make_n_tasks(1, second_type)
          make_n_tasks(3)
        }

        it 'it does not remove anything' do
          expect(remover).to_not receive(:remove_task)

          remover.remove(default_type)
        end
      end

      context 'when there is one more than max_tasks tasks of the given type in the database' do
        before {
          make_n_tasks(1, second_type)
          make_n_tasks(4)
        }

        it 'removes the first created one of the given type' do
          expect(remover).to receive(:remove_task).with(Bosh::Director::Models::Task[2])

          remover.remove(default_type)
        end
      end

      context 'when there are 2 more than max_tasks task of the given type in the database' do
        before {
          make_n_tasks(1, second_type)
          make_n_tasks(5)
        }

        it 'removes the first two created tasks of the given type' do
          expect(remover).to receive(:remove_task).with(Bosh::Director::Models::Task[2])
          expect(remover).to receive(:remove_task).with(Bosh::Director::Models::Task[3])

          remover.remove(default_type)
        end
      end

      context 'when there are 10 more than max_tasks task of the given type in the database' do
        before {
          make_n_tasks(1, second_type)
          make_n_tasks(13)
        }

        it 'removes 2 tasks older than the latest max_tasks of the given type' do
          expect(remover).to receive(:remove_task).with(Bosh::Director::Models::Task[11])
          expect(remover).to receive(:remove_task).with(Bosh::Director::Models::Task[10])

          remover.remove(default_type)
        end
      end

      context 'when there are 2 types with more than max_tasks tasks in the database' do
        before {
          make_n_tasks(4, second_type)
          make_n_tasks(4)
        }

        it 'keeps the tasks which have a different type' do
          (1..4).each do |id|
            expect(remover).to_not receive(:remove_task).with(Bosh::Director::Models::Task[id])
          end

          remover.remove(default_type)
        end
      end

      context 'when specific states should be ignored from removal' do
        before do
          make_n_tasks(1, second_type)
          make_n_tasks(5)
          running_task = Bosh::Director::Models::Task[2]
          running_task.update({:state => state})
        end

        context 'state is processing' do
          let(:state) { :processing }

          it 'removes task older than the latest max_tasks that do not correspond to a task that is in a processing state' do
            expect(remover).to receive(:remove_task).with(Bosh::Director::Models::Task[3])

            remover.remove(default_type)
          end
        end

        context 'state is queued' do
          let (:state) { :queued }

          it 'removes task older than the latest max_tasks that do not correspond to a task that is in a queued state' do
            expect(remover).to receive(:remove_task).with(Bosh::Director::Models::Task[3])

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
          expect {
            remover.remove(default_type)
          }.to_not raise_error
        end
      end

      context 'when a task has teams' do
        before do
          make_n_tasks(4)
          team = Bosh::Director::Models::Team.make(name: 'ateam')
          task = Bosh::Director::Models::Task[1]
          task.add_team(team)
        end

        it 'is removed' do
          expect(Bosh::Director::Models::Task[1].teams.first.name).to eq('ateam')
          expect {
            remover.remove(default_type)
          }.to change {
            Bosh::Director::Models::Task.count
          }.from(4).to(3)
        end
      end
    end

    describe '#remove_task' do
      before do
        make_n_tasks(2)
      end

      it 'removes task from data base' do
        expect {
          remover.remove_task(Bosh::Director::Models::Task[1])
        }.to change {
          Bosh::Director::Models::Task[1]
        }.from(Bosh::Director::Models::Task[1]).to(nil)

        expect(Bosh::Director::Models::Task[2]).to_not be_nil
      end

      it 'removes files belonging to task' do
        expect {
          remover.remove_task(Bosh::Director::Models::Task[1])
        }.to change {
          Dir["/director/tasks/#{default_type}_*"].count
        }.from(2).to(1)

        expect(Dir['/director/tasks/type_1']).to_not be_nil
      end

      it 'does not fail when called multiple times on the same task' do
        expect {
          task = Bosh::Director::Models::Task[1]
          remover.remove_task(task)
          remover.remove_task(task)
        }.to_not raise_error
      end
    end
  end
end
