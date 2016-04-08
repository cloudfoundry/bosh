require 'spec_helper'
require 'fakefs/spec_helpers'
require 'bosh/director/api/task_remover'

module Bosh::Director::Api
  describe TaskRemover do
    describe '#remove' do
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
      context 'when there are fewer than max_tasks task of the given type in the database' do
        before {
          make_n_tasks(1, second_type)
          make_n_tasks(2)
        }

        it 'keeps all tasks files' do
          expect {
            remover.remove(default_type)
          }.not_to change {
            Dir['/director/tasks/**/*']
          }
        end

        it 'keeps all tasks in the database' do
          expect {
            remover.remove(default_type)
          }.not_to change {
            Bosh::Director::Models::Task.count
          }
        end
      end

      context 'when there are exactly max_tasks of the given type in the database' do
        before {
          make_n_tasks(1, second_type)
          make_n_tasks(3)
        }

        it 'keeps all tasks files' do
          expect {
            remover.remove(default_type)
          }.not_to change {
            Dir['/director/tasks/**/*']
          }
        end

        it 'keeps all tasks in the database' do
          expect {
            remover.remove(default_type)
          }.not_to change {
            Bosh::Director::Models::Task.count
          }
        end
      end

      context 'when there is one more than max_tasks tasks of the given type in the database' do
        before {
          make_n_tasks(1, second_type)
          make_n_tasks(4)
        }

        it 'keeps the latest max_tasks tasks files' do
          expect {
            remover.remove(default_type)
          }.to change {
            Dir["/director/tasks/#{default_type}_*"]
          }.from(
            (0...4).map {|i| "/director/tasks/#{default_type}_#{i}"}
          ).to(
            (1...4).map { |i| "/director/tasks/#{default_type}_#{i}" }
          )
          expect(File.exist?("/director/tasks/#{second_type}_0")).to be(true)
        end

        it 'keeps the latest max_tasks tasks in the database' do
          expect {
            remover.remove(default_type)
          }.to change {
            Bosh::Director::Models::Task.filter(:type => default_type).count
          }.from(4).to(3)
          expect(Bosh::Director::Models::Task.filter(:type => second_type).count).to eq(1)
        end
      end

      context 'when there are 2 more than max_tasks task of the given type in the database' do
        before {
          make_n_tasks(1, second_type)
          make_n_tasks(5)
        }

        it 'removes the oldest 2 tasks files because it eventually converges to max_tasks' do
          expect {
            remover.remove(default_type)
          }.to change {
            Dir["/director/tasks/#{default_type}_*"]
          }.from(
                 (0...5).map {|i| "/director/tasks/#{default_type}_#{i}"}
               ).to(
                 (2...5).map { |i| "/director/tasks/#{default_type}_#{i}" }
               )
          expect(File.exist?("/director/tasks/#{second_type}_0")).to be(true)
        end

        it 'removes the oldest 2 database entries because it eventually converges to max_tasks' do
          expect {
            remover.remove(default_type)
          }.to change {
            Bosh::Director::Models::Task.filter(:type => default_type).count
          }.from(5).to(3)
          expect(Bosh::Director::Models::Task.filter(:type => second_type).count).to eq(1)
        end
      end

      context 'when there are 10 more than max_tasks task of the given type in the database' do
        before {
          make_n_tasks(1, second_type)
          make_n_tasks(13)
        }

        it 'removes 2 files older than the latest max_tasks because it eventually converges to max_tasks' do
          expect {
            remover.remove(default_type)
          }.to change {

            Dir["/director/tasks/#{default_type}_*"].sort
          }.from(
            (0...13).map { |i| "/director/tasks/#{default_type}_#{i}" }.sort
          ).to(
            ((0...8).to_a + (10...13).to_a).map { |i| "/director/tasks/#{default_type}_#{i}" }.sort
          )
          expect(File.exist?("/director/tasks/#{second_type}_0")).to be(true)
        end

        it 'removes the 2 database entries older than the latest max_tasks because it eventually converges to max_tasks' do
          expect {
            remover.remove(default_type)
          }.to change {
            Bosh::Director::Models::Task.filter(:type => default_type).map(:id)
          }.from((2..14).to_a).to((2..14).to_a - [10,11])
          expect(Bosh::Director::Models::Task.filter(:type => second_type).count).to eq(1)
        end
      end

      context 'when there are 2 types with more than max_tasks tasks in the database' do
        before {
          make_n_tasks(4, second_type)
          make_n_tasks(4)
        }

        it 'keeps the task files which have different type' do
          expect {
            remover.remove(default_type)
          }.not_to change {
            Dir["/director/tasks/#{second_type}_*"]
          }
        end

        it 'keeps the database entries for tasks which have different type' do
          expect {
            remover.remove(default_type)
          }.not_to change {
           Bosh::Director::Models::Task.filter(:type => second_type).count}
        end
      end

      context 'when a processing task is too old' do
        before do
          make_n_tasks(1, second_type)
          make_n_tasks(5)
          running_task = Bosh::Director::Models::Task[2]
          running_task.update({:state => :processing})
        end

        it 'removes file older than the latest max_tasks that do not correspond to a task that is in a processing state' do
          expect {
            remover.remove(default_type)
          }.to change {
            Dir["/director/tasks/#{default_type}_*"].sort
          }.from(
            (0...5).map { |i| "/director/tasks/#{default_type}_#{i}" }.sort
          ).to(
            ([0] + (2...5).to_a).map { |i| "/director/tasks/#{default_type}_#{i}" }.sort
          )
          expect(File.exist?("/director/tasks/#{second_type}_0")).to be(true)
        end

        it 'removes the database entry for a task of the given type older than the latest max_tasks that is not in a processing state' do
          expect {
            remover.remove(default_type)
          }.to change {
            Bosh::Director::Models::Task.filter(:type => default_type).map(:id)
          }.from((2..6).to_a).to((2..6).to_a - [3])
          expect(Bosh::Director::Models::Task.filter(:type => second_type).count).to eq(1)
        end
      end

      context 'when a queued task is too old' do
        before do
          make_n_tasks(1, second_type)
          make_n_tasks(5)
          running_task = Bosh::Director::Models::Task[2]
          running_task.update({:state => :queued})
        end

        it 'removes file older than the latest max_tasks that do not correspond to a task that is in a queued state' do
          expect {
            remover.remove(default_type)
          }.to change {
            Dir["/director/tasks/#{default_type}_*"].sort
          }.from(
                 (0...5).map { |i| "/director/tasks/#{default_type}_#{i}" }.sort
               ).to(
                 ([0] + (2...5).to_a).map { |i| "/director/tasks/#{default_type}_#{i}" }.sort
               )
          expect(File.exist?("/director/tasks/#{second_type}_0")).to be(true)
        end

        it 'removes the database entry for a task of the given type older than the latest max_tasks that is not in a queued state' do
          expect {
            remover.remove(default_type)
          }.to change {
            Bosh::Director::Models::Task.filter(:type => default_type).map(:id)
          }.from((2..6).to_a).to((2..6).to_a - [3])
          expect(Bosh::Director::Models::Task.filter(:type => second_type).count).to eq(1)
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
    end
  end
end
