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
    before do
      allow(ForkedProcess).to receive(:run).and_yield.and_return(process_status)
    end

    let(:args) { ['1', '2'] }

    it "doesn't accept job class that is not a subclass of base job" do
      expect {
        Jobs::DBJob.new(Class.new, task.id, args)
      }.to raise_error(DirectorError, /invalid director job/i)
    end

    it "doesn't accept job class that does not have \perform' method" do
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

    it 'raises error when task is not in queue state' do
      task.update(state: 'processing')
      expect { db_job.perform }.to raise_error(DirectorError, "Cannot perform job for task #{task.id} (not in 'queued' state)")
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
      it 'retries on Sequel::DatabaseConnectionError' do
        expect(Models::Task).to receive(:first).and_raise(Sequel::DatabaseConnectionError).once.ordered
        expect(Models::Task).to receive(:first).and_return(task).ordered

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
end
