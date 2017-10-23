require 'spec_helper'

module Bosh::Director

  class MyError < StandardError
  end

  describe Jobs::DBJob do

    let (:db_job) { Jobs::DBJob.new(job_class, task.id, args) }
    let(:job_class) do
      Class.new(Jobs::BaseJob) do
        def perform
          'foo'
        end

        def self.perform(*args)
          'foo'
        end

        @queue = :normal
      end
    end
    let(:task) { Models::Task.make(id: 42) }
    let(:process_status) { instance_double(Process::Status, :signaled? => signaled) }
    let(:signaled) { false }
    let(:task_dataset) { instance_double(Sequel::Dataset) }

    let(:args) { ['1', '2'] }

    context 'fake fork' do
      let(:delayed_job) { instance_double(Delayed::Backend::Sequel::Job, locked_by: 'workername1') }

      before do
        db_job.before(delayed_job)
        allow(ForkedProcess).to receive(:run).and_yield.and_return(process_status)
      end

      it "doesn't accept job class that is not a subclass of base job" do
        expect {
          Jobs::DBJob.new(Class.new, task.id, args)
        }.to raise_error(DirectorError, /invalid director job/i)
      end

      it "doesn't accept job class that does not have 'perform' method" do
        job_class_without_perform = Class.new(Jobs::BaseJob) do
          @queue = :normal
        end

        expect {
          Jobs::DBJob.new(job_class_without_perform, task.id, args)
        }.to raise_error(DirectorError, /invalid director job/i)
      end

      it "doesn't accept job class without queue value" do
        job_class_without_queue = Class.new(Jobs::BaseJob) do
          define_method :perform do
            'foo'
          end
        end

        expect {
          Jobs::DBJob.new(job_class_without_queue, task.id, args)
        }.to raise_error(DirectorError, /invalid director job/i)
      end

      context 'task state must transition from queued to processed' do
        it 'always updates state' do
          db_job.perform
          expect(Models::Task.where(id: task.id ).first.state).to eq('processing')
        end

        it 'safely updates the task once and only once (to avoid two jobs separately trying to claim the task)' do
          expect(task_dataset).to receive(:update).once.and_return(1)
          expect(Models::Task).to receive(:where).once.and_return(task_dataset)

          db_job.perform
        end

        it 'raises error when task is not in queue state' do
          task.update(state: 'processing')
          expect { db_job.perform }.to raise_error(DirectorError, "Cannot perform job for task #{task.id} (not in 'queued' state)")
      end
      end

      context 'when forked process is signaled' do
        let(:signaled) { true }
        it 'fails task' do
          allow(db_job).to receive(:puts) # suppress the noise, failing to use Logging::Logger in multithreaded calls
          allow(job_class).to receive(:perform).with(task.id, 'workername1', *args)
          db_job.perform
          expect(Models::Task.first(id: 42).state).to eq('error')
        end
      end

      it 'performs new job' do
        expect(job_class).to receive(:perform).with(task.id, 'workername1', *args)
        db_job.perform
      end

      it 'gets queue name from job class' do
        expect(db_job.queue_name).to eq(:normal)
      end

      context 'when worker should have access to filesystem' do
        let(:job_class) do
          Class.new(Jobs::BaseJob) do
            define_method :perform do
              'foo'
            end
            @queue = :normal
            @local_fs = true
          end
        end

        before { allow(Config).to receive(:director_pool).and_return('local.hostname') }

        it 'set specific queue for the job' do
          expect(db_job.queue_name).to eq('local.hostname')
        end
      end

      context 'when db connection times out when pulling record' do
        before do
          allow(task_dataset).to receive(:update).once.and_return(1)
        end

        it 'retries on Sequel::DatabaseConnectionError' do
          expect(Models::Task).to receive(:where).and_raise(Sequel::DatabaseConnectionError).once.ordered
          expect(Models::Task).to receive(:where).and_return(task_dataset).ordered

          db_job.perform
        end
      end

      context 'passing arguments to executed jobs' do
        let(:job_class) do
          Class.new(Jobs::BaseJob) do
            @queue = :normal

            def perform
              true
            end
          end
        end

        context 'without arguments' do
          let(:args) { nil }

          it 'executes arguments' do
            expect(job_class).to receive(:perform).with(task.id, nil).and_return nil

            Bosh::Director::Jobs::DBJob.new(job_class, task.id, args).perform
          end
        end

        context 'with basic arguments' do
          let(:args) { [ 'string', 0, false ] }

          it 'executes arguments' do
            expect(job_class).to receive(:perform).with(task.id, nil, 'string', 0, false).and_return nil

            Bosh::Director::Jobs::DBJob.new(job_class, task.id, args).perform
          end
        end
      end
    end

    context 'testing forked process behavior' do
      before do
        allow(Process).to receive(:fork).and_yield.and_return(-1)
        allow(Process).to receive(:waitpid).with(-1)
      end

      let(:em_event_loop_exception_message) {'EM event loop exception raised OMG'}
      let(:em_thread_exception_message) {'EM defer thread exception raised OMG'}

      it 'emits exceptions raised in the EM event loop to the logger' do
        expect(Config.logger).to receive(:error) do |message|
          expect(message).to match(em_event_loop_exception_message)
          expect(message).to_not match(em_thread_exception_message)
        end

        expect {
          Bosh::Director::ForkedProcess.run do
            EM.schedule do
              raise MyError, em_event_loop_exception_message
            end
            sleep 10
            raise MyError, em_event_loop_exception_message
          end
        }.to raise_error MyError, em_event_loop_exception_message
      end

      it 'emits exceptions raised in the EM operation thread to the logger' do
        expect(Config.logger).to receive(:error) do |message|
          expect(message).to match(em_thread_exception_message)
        end

        expect {
          Bosh::Director::ForkedProcess.run do
            EM.schedule do
              puts 'doing complex processing'
            end
            raise MyError, em_thread_exception_message
          end
        }.to raise_error MyError, em_thread_exception_message
      end
    end
  end
end
