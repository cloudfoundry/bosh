# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

module Bosh::Director
  describe JobRunner do
    let(:sample_job_class) do
      Class.new(Jobs::BaseJob) do
        define_method :perform do
          'foo'
        end
      end
    end

    before do
      Config.stub(:cloud_options).and_return({})
      @task_dir = Dir.mktmpdir
      @task = Models::Task.make(id: 42, output: @task_dir)
    end

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
      @task.reload
      @task.state.should == 'done'
      @task.result.should == 'foo'
    end

    it 'whines when no task is found' do
      expect {
        make_runner(sample_job_class, 155)
      }.to raise_error(TaskNotFound)
    end

    it 'whines when task directory is missing' do
      @task.output = nil
      @task.save
      expect {
        make_runner(sample_job_class, 42)
      }.to raise_error(DirectorError, /directory.*missing/)
    end

    it 'sets up task logs: debug, event, result' do
      event_log = double('event log')
      debug_log = Logger.new(StringIO.new)
      result_file = double('result file')

      EventLog::Log
        .stub(:new)
        .with(File.join(@task_dir, 'event'))
        .and_return(event_log)

      Logger.stub(:new).with(File.join(@task_dir, 'debug')).and_return(debug_log)

      TaskResultFile.stub(:new).
        with(File.join(@task_dir, 'result')).
        and_return(result_file)

      make_runner(sample_job_class, 42)

      config = Config
      config.event_log.should == event_log
      config.logger.should == debug_log
      config.result.should == result_file
    end

    it 'handles task cancellation' do
      job = Class.new(Jobs::BaseJob) do
        define_method(:perform) do |*args|
          raise TaskCancelled, 'task cancelled'
        end
      end

      make_runner(job, 42).run
      @task.reload
      @task.state.should == 'cancelled'
    end

    it "doesn't update task state when checkpointing" do
      task = Models::Task[42]
      task.update(:state => 'processing')

      runner = make_runner(sample_job_class, 42)

      task.update(:state => 'cancelling')
      runner.checkpoint

      @task.reload
      @task.state.should == 'cancelling'
    end

    it 'handles task error' do
      job = Class.new(Jobs::BaseJob) do
        define_method(:perform) { |*args| raise 'Oops' }
      end

      make_runner(job, 42).run
      @task.reload
      @task.state.should == 'error'
      @task.result.should == 'Oops'
    end
  end
end
