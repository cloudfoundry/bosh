# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

module Bosh::Director
  describe Jobs::BaseJob do
    before do
      Config.stub(:cloud_options).and_return({})
      @task_dir = Dir.mktmpdir
      @event_log = EventLog::Log.new(StringIO.new)
      @logger = Logger.new(StringIO.new)

      Logger.stub(:new).with("#{@task_dir}/debug").and_return(@logger)
      EventLog::Log.stub(:new).with("#{@task_dir}/event").
        and_return(@event_log)
      @result_file = double('result-file')
      TaskResultFile.stub(:new).with("#{@task_dir}/result").
        and_return(@result_file)
    end

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

      task = Models::Task.make(:id => 1, :output => @task_dir)

      testjob_class.perform(1)

      task.refresh
      task.state.should == 'done'
      task.result.should == '5'

      Config.logger.should eql(@logger)
    end

    it 'should pass on the rest of the arguments to the actual job' do
      testjob_class = Class.new(Jobs::BaseJob) do
        define_method :initialize do |*args|
          @args = args
        end

        define_method :perform do
          Yajl::Encoder.encode(@args)
        end
      end

      task = Models::Task.make(:output => @task_dir)

      testjob_class.perform(1, 'a', [:b], {:c => 5})

      task.refresh
      task.state.should == 'done'
      Yajl::Parser.parse(task.result).should == ['a', ['b'], {'c' => 5}]
    end

    it 'should record the error when there is an exception' do
      testjob_class = Class.new(Jobs::BaseJob) do
        define_method :perform do
          raise 'test'
        end
      end

      task = Models::Task.make(:id => 1, :output => @task_dir)

      testjob_class.perform(1)

      task.refresh
      task.state.should == 'error'
      task.result.should == 'test'
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
      task = Models::Task.make(:id => 1, :output => @task_dir,
                               :state => 'cancelling')

      described_class.perform(1)
      task.refresh
      task.state.should == 'cancelled'
      Config.logger.should eql(@logger)
    end

    it 'should cancel timeout-task' do
      task = Models::Task.make(:id => 1, :output => @task_dir,
                               :state => 'timeout')

      described_class.perform(1)
      task.refresh
      task.state.should == 'cancelled'
      Config.logger.should eql(@logger)
    end

  end
end
