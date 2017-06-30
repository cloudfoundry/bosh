require 'spec_helper'

module Bosh::Director
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
      before do
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
          allow(job_class).to receive(:perform).with(task.id, *args)
          db_job.perform
          expect(Models::Task.first(id: 42).state).to eq('error')
        end
      end

      it 'performs new job' do
        expect(job_class).to receive(:perform).with(task.id, *args)
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
            expect(job_class).to receive(:perform).with(task.id).and_return nil

            Bosh::Director::Jobs::DBJob.new(job_class, task.id, args).perform
          end
        end

        context 'with basic arguments' do
          let(:args) { [ 'string', 0, false ] }

          it 'executes arguments' do
            expect(job_class).to receive(:perform).with(task.id, 'string', 0, false).and_return nil

            Bosh::Director::Jobs::DBJob.new(job_class, task.id, args).perform
          end
        end
      end
    end

    # since we're forking, we require a database that supports concurrent connections
    context 'testing forked process behavior', if: ENV.fetch('DB', 'sqlite') != 'sqlite' do
      let!(:state) { Tempfile.new }

      after { state.unlink }

      it 'emits exceptions to the logger' do
        allow(Config.logger).to receive(:error) do |message|
          # this is executed only by the fork'd process
          state.write(message)
        end

        Bosh::Director::ForkedProcess.run do
          until EM.reactor_running? do
            sleep 1
          end

          # since this fork will emit an [expected] error, avoid outputting and confusing us
          $stderr.reopen('/dev/null')

          nats = Bosh::Director::NatsRpc.new('http://127.0.0.1:12345')
          nats.send_message('topic', {})

          sleep 15

          raise 'should never happen since rpc will fail to connect'
        end

        state.rewind
        state_data = state.read

        expect(state_data.split("\n")[0]).to eq("Fatal error from event machine: Could not connect to server on http://127.0.0.1:12345")

        # we should also be including the backtrace
        expect(state_data).to match(%r{/gems/nats-})
        expect(state_data).to match(%r{/gems/eventmachine-})
      end
    end
  end
end
