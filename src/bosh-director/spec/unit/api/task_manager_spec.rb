require 'spec_helper'

module Bosh::Director
  module Api
    describe TaskManager do
      let(:manager) { described_class.new }

      describe '#decompress' do
        it 'should decompress a .gz file' do
          Dir.mktmpdir do |dir|
            FileUtils.cp(asset_path('foobar.gz'), dir)
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
          [FactoryBot.create(:models_task,
            type: :update_deployment,
            state: state,
          ),
           FactoryBot.create(:models_task,
             type: :cck_scan_and_fix,
             state: state,
             deployment_name: 'dummy',
           )]
        end
        let!(:tasks_processing) do
          [FactoryBot.create(:models_task,
            type: :update_deployment,
            state: :processing,
            deployment_name: 'not-dummy',
          ),
           FactoryBot.create(:models_task,
             type: :ssh,
             state: :processing,
             deployment_name: 'dummy',
           )]
        end

        let(:tasks) do
          manager.select(selector)
        end

        context 'when selector is partially invalid' do
          context 'by using nil selector' do
            let(:selector) { nil }
            it 'selects all queued tasks (which is the default)' do
              expect(tasks).to match_array(tasks_queued)
            end
          end

          context 'by not using array for state value' do
            let(:selector) { { 'states' => 'processing' } }
            it 'selects all queued tasks (which is the default)' do
              expect(tasks).to match_array(tasks_queued)
            end
          end

          context 'by using empty array for state value' do
            let(:selector) { { 'states' => [] } }
            it 'selects all queued tasks (which is the default)' do
              expect(tasks).to match_array(tasks_queued)
            end
          end

          context 'by not using array for type value' do
            let(:selector) { { 'types' => 'update_deployment' } }
            it 'selects all queued tasks (which is the default)' do
              expect(tasks).to match_array(tasks_queued)
            end
          end

          context 'by using invalid state but valid type selector' do
            let(:selector) do
              {
                'types' => %w[update_deployment],
                'states' => 'processing',
              }
            end
            it 'selects queued tasks (which is the default) respecting the type' do
              expect(tasks).to contain_exactly(tasks_queued[0])
            end
          end

          context 'by using invalid type but valid state selector' do
            let(:selector) do
              {
                'types' => 'update_deployment',
                'states' => %w[processing],
              }
            end
            it 'selects all types (which is the default) but respecting state' do
              expect(tasks).to match_array(tasks_processing)
            end
          end
        end

        context 'when using valid selector' do
          context 'when deployment is given' do
            let(:selector) { { 'deployment' => 'dummy' } }
            it 'selects all queued tasks for this deployment' do
              expect(tasks).to contain_exactly(tasks_queued[1])
            end
          end

          context 'with single type selector' do
            let(:selector) { { 'types' => %w[cck_scan_and_fix] } }
            it 'selects only tasks of that type' do
              expect(tasks).to contain_exactly(tasks_queued[1])
            end
          end

          context 'with multiple types selector' do
            let(:selector) { { 'types' => %w[cck_scan_and_fix update_deployment] } }
            it "selects only tasks of these types with the default state 'queued'" do
              expect(tasks).to match_array(tasks_queued)
            end
          end

          context 'with single state selector' do
            let(:selector) { { 'states' => %w[processing] } }
            it 'selects only tasks of that state' do
              expect(tasks).to match_array(tasks_processing)
            end
          end

          context 'with multiple states selector' do
            let(:selector) { { 'states' => %w[processing queued] } }
            it 'selects only tasks of these states' do
              expect(tasks).to match_array([tasks_queued, tasks_processing].flatten)
            end
          end

          context 'with both type and state selector' do
            let(:selector) do
              { 'types' => %w[update_deployment],
                'states' => %w[queued] }
            end
            it 'selects tasks of that type and state' do
              expect(tasks).to contain_exactly(tasks_queued[0])
            end
          end
        end
      end

      describe '#cancel' do
        let(:state) { :processing }
        let!(:task) do
          FactoryBot.create(:models_task,
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
          FactoryBot.create(:models_task,
            type: :update_deployment,
            state: :timeout,
          )
        end
        let!(:cancellable_task) do
          FactoryBot.create(:models_task,
            type: :update_deployment,
            state: :processing,
          )
        end

        it 'logs non-cancellable tasks' do
          expect(logger).to receive(:info).with("Cannot cancel task #{non_cancellable_task.id}: invalid state (timeout)")
          manager.cancel_tasks([cancellable_task, non_cancellable_task])
        end

        it 'cancels cancellable tasks' do
          manager.cancel_tasks([cancellable_task, non_cancellable_task])
          expect(cancellable_task.state).to eq('cancelling')
        end
      end

      describe '#task_to_hash' do
        let!(:finished_task) do
          FactoryBot.create(:models_task,
            type: :update_deployment,
            state: :timeout,
            started_at: Time.now,
            timestamp: Time.now,
          )
        end
        let!(:unfinished_task) do
          FactoryBot.create(:models_task,
            type: :update_deployment,
            state: :processing,
            started_at: Time.now,
            timestamp: Time.now,
          )
        end

        it 'nils out the timestamp for tasks that are not finished' do
          expect(manager.task_to_hash(unfinished_task)['timestamp']).to be_nil
        end

        it 'shows the persisted timestamp for tasks that are finished' do
          expect(manager.task_to_hash(finished_task)['timestamp']).not_to be_nil
        end
      end
    end
  end
end
