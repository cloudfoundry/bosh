# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::JobRunner do

  before(:each) do
    @task_dir = Dir.mktmpdir
    @task = Bosh::Director::Models::Task.make(:id => 42, :output => @task_dir)

    @sample_job = Class.new(Bosh::Director::Jobs::BaseJob) do
      define_method(:perform) { |*args| "foo" }
    end
  end

  def make_runner(job_class, task_id)
    Bosh::Director::JobRunner.new(job_class, task_id)
  end

  it "doesn't accept job class that is not a subclass of base job" do
    expect {
      make_runner(Class.new, 42)
    }.to raise_error(Bosh::Director::DirectorError, /invalid director job/i)
  end

  it "performs the requested job with provided args" do
    runner = make_runner(@sample_job, 42)
    runner.run(1, 2, 3)
    @task.reload
    @task.state.should == "done"
    @task.result.should == "foo"
  end

  it "whines when no task is found" do
    expect {
      make_runner(@sample_job, 155)
    }.to raise_error(Bosh::Director::TaskNotFound)
  end

  it "whines when task directory is missing" do
    @task.output = nil
    @task.save
    expect {
      make_runner(@sample_job, 42)
    }.to raise_error(Bosh::Director::DirectorError, /directory.*missing/)
  end

  it "sets up task logs: debug, event, result" do
    event_log = mock("event log")
    debug_log = Logger.new(StringIO.new)
    result_file = mock("result file")

    Bosh::Director::EventLog.stub!(:new).with(File.join(@task_dir, "event")).
      and_return(event_log)

    Logger.stub!(:new).with(File.join(@task_dir, "debug")).and_return(debug_log)

    Bosh::Director::TaskResultFile.stub!(:new).
      with(File.join(@task_dir, "result")).
      and_return(result_file)

    make_runner(@sample_job, 42)

    config = Bosh::Director::Config
    config.event_log.should == event_log
    config.logger.should == debug_log
    config.result.should == result_file
  end

  it "handles task cancellation" do
    job = Class.new(Bosh::Director::Jobs::BaseJob) do
      define_method(:perform) do |*args|
        raise Bosh::Director::TaskCancelled, "task cancelled"
      end
    end

    make_runner(job, 42).run
    @task.reload
    @task.state.should == "cancelled"
  end

  it "handles task error" do
    job = Class.new(Bosh::Director::Jobs::BaseJob) do
      define_method(:perform) { |*args| raise "Oops" }
    end

    make_runner(job, 42).run
    @task.reload
    @task.state.should == "error"
    @task.result.should == "Oops"
  end

end