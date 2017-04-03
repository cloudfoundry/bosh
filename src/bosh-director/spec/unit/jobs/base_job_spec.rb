require 'spec_helper'

module Bosh::Director
  describe Jobs::BaseJob do
    let(:task_id) { 1 }
    let(:tasks_dir) { Dir.mktmpdir }
    let(:task_dir) { File.join(tasks_dir, 'tasks', task_id.to_s) }
    before { allow(Config).to receive(:base_dir).and_return(tasks_dir) }
    before { allow(Config).to receive(:cloud_options).and_return({}) }

    describe 'described_class.job_type' do
      it 'should complain that the method is not implemented' do
        expect { described_class.job_type }.to raise_error(NotImplementedError)
      end
    end

    it 'should set up the task' do
      testjob_class = Class.new(Jobs::BaseJob) do
        define_method :perform do
          5
        end
      end

      task = Models::Task.make(:id => task_id, :output => task_dir)

      testjob_class.perform(task_id)

      task.refresh
      expect(task.state).to eq('done')
      expect(task.result).to eq('5')

      expect(Config.logger).to be_a_kind_of(Logging::Logger)
    end

    it 'should pass on the rest of the arguments to the actual job' do
      testjob_class = Class.new(Jobs::BaseJob) do
        define_method :initialize do |*args|
          @args = args
        end

        define_method :perform do
          JSON.generate(@args)
        end
      end

      task = Models::Task.make(:output => task_dir)

      testjob_class.perform(task_id, 'a', [:b], {:c => 5})

      task.refresh
      expect(task.state).to eq('done')
      expect(JSON.parse(task.result)).to eq(['a', ['b'], {'c' => 5}])
    end

    it 'should record the error when there is an exception' do
      testjob_class = Class.new(Jobs::BaseJob) do
        define_method :perform do
          raise 'test'
        end
      end

      task = Models::Task.make(:id => task_id, :output => task_dir)

      testjob_class.perform(1)

      task.refresh
      expect(task.state).to eq('error')
      expect(task.result).to eq('test')
    end

    it 'should raise an exception when the task was not found' do
      testjob_class = Class.new(Jobs::BaseJob) do
        define_method :perform do
          fail
        end
      end

      expect { testjob_class.perform(1) }.to raise_exception(TaskNotFound)
    end

    it 'should cancel task' do
      task = Models::Task.make(:id => 1, :output => task_dir,
                               :state => 'cancelling')

      described_class.perform(1)
      task.refresh
      expect(task.state).to eq('cancelled')
      expect(Config.logger).to be_a_kind_of(Logging::Logger)
    end

    it 'should cancel timeout-task' do
      task = Models::Task.make(:id => task_id, :output => task_dir,
                               :state => 'timeout')

      described_class.perform(task_id)
      task.refresh
      expect(task.state).to eq('cancelled')
      expect(Config.logger).to be_a_kind_of(Logging::Logger)
    end

    describe '#task_checkpoint' do
      subject { job.task_checkpoint }

      let(:job) { described_class.new }

      it_behaves_like 'raising an error when a task has timed out or been canceled'
    end
  end
end
