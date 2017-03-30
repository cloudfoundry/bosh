require 'spec_helper'
require 'logging'

module Bosh::Director
  describe JobRunner do
    let(:sample_job_class) do
      Class.new(Jobs::BaseJob) do
        define_method :perform do
          'foo'
        end
      end
    end

    let(:task) { Models::Task.make(id: 42) }

    let(:tasks_dir) { Dir.mktmpdir }
    before { allow(Config).to receive(:base_dir).and_return(tasks_dir) }
    after { FileUtils.rm_rf(tasks_dir) }

    let(:task_dir) { File.join(tasks_dir, 'tasks', task.id.to_s) }
    before { FileUtils.mkdir_p(task_dir) }

    before { allow(Config).to receive(:cloud_options).and_return({}) }

    def make_runner(job_class, task_id)
      JobRunner.new(job_class, task_id)
    end

    it "doesn't accept job class that is not a subclass of base job" do
      expect {
        make_runner(Class.new, 42)
      }.to raise_error(DirectorError, /invalid director job/i)
    end

    it 'performs the requested job with provided args' do
      runner = make_runner(sample_job_class, 42)
      runner.run
      task.reload
      expect(task.state).to eq('done')
      expect(task.result).to eq('foo')
    end

    it 'whines when no task is found' do
      expect {
        make_runner(sample_job_class, 155)
      }.to raise_error(TaskNotFound)
    end

    context 'when task directory is missing' do
      let(:task) { Models::Task.make(id: 188) }

      it 'creates task directory if it is missing' do
        task.save
        make_runner(sample_job_class, 188)
        expect(File).to exist(task_dir)
      end
    end

    it 'sets up task logs: debug, event, result' do
      event_log = double('event log')
      task_result = double('result file')

      task_writer = TaskDBWriter.new(:event_output, task.id)
      allow(TaskDBWriter).to receive(:new).
        with(:event_output, task.id).and_return(task_writer)

      allow(EventLog::Log)
        .to receive(:new)
        .with(task_writer)
        .and_return(event_log)

      allow(TaskDBWriter).to receive(:new).
        with(:result_output, task.id).
        and_return(task_result)

      make_runner(sample_job_class, 42)

      logger_repo = Logging::Repository.instance()

      config = Config
      expect(config.event_log).to eq(event_log)
      expect(config.logger).to eq(logger_repo.fetch('DirectorJobRunner'))
      expect(config.result).to eq(task_result)
    end

    it 'handles task cancellation' do
      job = Class.new(Jobs::BaseJob) do
        define_method(:perform) do |*args|
          raise TaskCancelled, 'task cancelled'
        end
      end

      make_runner(job, 42).run
      task.reload
      expect(task.state).to eq('cancelled')
    end

    it 'handles task error' do
      job = Class.new(Jobs::BaseJob) do
        define_method(:perform) { |*args| raise 'Oops' }
      end

      make_runner(job, 42).run
      task.reload
      expect(task.state).to eq('error')
      expect(task.result).to eq('Oops')
    end

    context 'when a job is being dry-run' do
      let(:sample_job_class) do
        Class.new(Jobs::BaseJob) do
          def dry_run?; true; end

          def perform
            Bosh::Director::Models::Dns::Domain.make
            Bosh::Director::Models::Instance.find(job: 'test').update(index: 2)
            'foo'
          end
        end
      end

      it 'should not alter the state of the database' do
        expect(Bosh::Director::Models::Dns::Domain.all).to be_empty
        Bosh::Director::Models::Instance.make(job: 'test', index: 1)

        runner = JobRunner.new(sample_job_class, 42)
        runner.run

        expect(Bosh::Director::Models::Dns::Domain.all).to be_empty
        expect(Bosh::Director::Models::Instance.find(job: 'test').index).to eq 1

        task.reload
        expect(task.state).to eq('done')
        expect(task.result).to eq('foo')
      end

      context 'when there is no dns' do
        let(:sample_job_class) do
          Class.new(Jobs::BaseJob) do
            def dry_run?; true; end

            def perform
              Bosh::Director::Models::Instance.find(job: 'test').update(index: 2)
              'foo'
            end
          end
        end

        it 'should not alter the state of the database' do
          Bosh::Director::Config.dns_db = nil
          Bosh::Director::Models::Instance.make(job: 'test', index: 1)

          runner = JobRunner.new(sample_job_class, 42)
          runner.run

          expect(Bosh::Director::Models::Instance.find(job: 'test').index).to eq 1

          task.reload
          expect(task.state).to eq('done')
          expect(task.result).to eq('foo')
        end
      end
    end
  end

  describe TaskCheckPointer do
    before { Models::Task.make(id: 42) }

    it 'updates task checkpoint time' do
      task = Models::Task[42]
      task.update(:state => 'processing')
      expect(task.checkpoint_time).to be(nil)
      TaskCheckPointer.new(task.id).checkpoint

      task.reload
      expect(task.checkpoint_time).to_not be(nil)
    end
  end
end
