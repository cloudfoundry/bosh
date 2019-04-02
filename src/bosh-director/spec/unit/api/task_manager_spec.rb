require 'spec_helper'

module Bosh::Director
  module Api
    describe TaskManager do
      let(:manager) { described_class.new }

      describe '#decompress' do
        it 'should decompress a .gz file' do
          Dir.mktmpdir do |dir|
            FileUtils.cp(asset('foobar.gz'), dir)
            src = File.join(dir, 'foobar.gz')
            dst = File.join(dir, 'foobar')

            expect(File.exist?(dst)).to be(false)

            manager.decompress(src, dst)

            expect(File.exist?(dst)).to be(true)
          end
        end

        it 'should not decompress if an uncompressed file exist' do
          Dir.mktmpdir do |dir|
            file = File.join(dir, 'file')
            file_gz = File.join(dir, 'file.gz')
            FileUtils.touch(file)
            FileUtils.touch(file_gz)

            expect(File).not_to receive(:open)

            manager.decompress(file_gz, file)
          end
        end
      end

      describe '#task_file' do
        let(:task) { double(Bosh::Director::Models::Task) }
        let(:task_dir) { '/var/vcap/store/director/tasks/1' }

        it 'should return the task output contents if the task output contents is not a directory' do
          allow(task).to receive_messages(output: 'task output')

          expect(manager.log_file(task, 'type')).to eq('task output')
        end

        it 'should return the task log path' do
          allow(task).to receive_messages(output: task_dir)
          allow(manager).to receive(:decompress)

          expect(File).to receive(:directory?).with(task_dir).and_return(true)

          manager.log_file(task, 'cpi')
        end
      end

      describe '#select' do
        let(:state) { :queued }
        let!(:tasks_queued) do
          [Models::Task.make(
            type: :update_deployment,
            state: state,
          ),
           Models::Task.make(
             type: :scan_and_fix,
             state: state,
           )]
        end
        let!(:task_processing) do
          Models::Task.make(
            type: :update_deployment,
            state: :processing,
          )
        end

        let(:tasks) do
          manager.select(selector)
        end

        context 'with nil selector' do
          let(:selector) { nil }
          it 'selects all queued tasks' do
            expect(tasks).to match_array(tasks_queued)
          end
        end

        context 'with type selector' do
          let(:selector) { { 'type' => 'scan_and_fix' } }
          it 'selects only tasks of that type' do
            expect(tasks).to contain_exactly(tasks_queued[1])
          end
        end

        context 'with state selector' do
          let(:selector) { { 'state' => 'processing' } }
          it 'selects only tasks of that state' do
            expect(tasks).to contain_exactly(task_processing)
          end
        end

        context 'with both type and state selector' do
          let(:selector) do
            { 'type' => 'update_deployment',
              'state' => 'queued' }
          end
          it 'selects  tasks of that type and state' do
            expect(tasks).to contain_exactly(tasks_queued[0])
          end
        end
      end

      describe '#cancel' do
        let(:state) { :processing }
        let!(:task) do
          Models::Task.make(
            type: :update_deployment,
            state: state,
          )
        end

        context 'when task can be cancelled' do
          it 'updates the task to be state cancelling' do
            allow(task).to receive_messages(cancellable?: true)

            manager.cancel(task)

            expect(task.state).to eq('cancelling')
          end
        end

        context 'when task cannot be cancelled' do
          it 'raises a TaskUnexpectedState error' do
            allow(task).to receive_messages(cancellable?: false)

            expect do
              manager.cancel(task)
            end.to(raise_error(TaskUnexpectedState))
          end
        end
      end

      describe '#cancel_tasks' do
        let!(:non_cancellable_task) do
          Models::Task.make(
            type: :update_deployment,
            state: :timeout,
          )
        end
        let!(:cancellable_task) do
          Models::Task.make(
            type: :update_deployment,
            state: :processing,
          )
        end

        it 'logs non-cancellable tasks' do
          expect(logger).to receive(:info).with('Cannot cancel task 1: invalid state (timeout)')
          manager.cancel_tasks([cancellable_task, non_cancellable_task])
        end

        it 'cancels cancellable tasks' do
          manager.cancel_tasks([cancellable_task, non_cancellable_task])
          expect(cancellable_task.state).to eq('cancelling')
        end
      end
    end
  end
end
