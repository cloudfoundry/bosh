# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::Jobs::BaseJob do

  before(:each) do
    @task_dir = Dir.mktmpdir
    @event_log = Bosh::Director::EventLog.new(StringIO.new)
    @logger = Logger.new(StringIO.new)

    Logger.stub!(:new).with("#{@task_dir}/debug").and_return(@logger)
    Bosh::Director::EventLog.stub!(:new).with("#{@task_dir}/event").
      and_return(@event_log)
    @result_file = mock("result-file")
    Bosh::Director::TaskResultFile.stub!(:new).with("#{@task_dir}/result").
      and_return(@result_file)
  end

  it "should set up the task" do
    test = Class.new(Bosh::Director::Jobs::BaseJob) do
      define_method :perform do
        5
      end
    end

    task = Bosh::Director::Models::Task.make(:id => 1, :output => @task_dir)

    test.perform(1)

    task.refresh
    task.state.should == "done"
    task.result.should == "5"

    Bosh::Director::Config.logger.should eql(@logger)
  end

  it "should pass on the rest of the arguments to the actual job" do
    test = Class.new(Bosh::Director::Jobs::BaseJob) do
      define_method :initialize do |*args|
        super(*args)
        @args = args
      end

      define_method :perform do
        Yajl::Encoder.encode(@args)
      end
    end

    task = Bosh::Director::Models::Task.make(:output => @task_dir)

    test.perform(1, "a", [:b], {:c => 5})

    task.refresh
    task.state.should == "done"
    Yajl::Parser.parse(task.result).should == ["a", ["b"], {"c" => 5}]
  end

  it "should record the error when there is an exception" do
    test = Class.new(Bosh::Director::Jobs::BaseJob) do
      define_method :perform do
        raise "test"
      end
    end

    task = Bosh::Director::Models::Task.make(:id => 1, :output => @task_dir)

    test.perform(1)

    task.refresh
    task.state.should == "error"
    task.result.should == "test"
  end

  it "should raise an exception when the task was not found" do
    test = Class.new(Bosh::Director::Jobs::BaseJob) do
      define_method :perform do
        fail
      end
    end

    lambda { test.perform(1) }.should raise_exception(Bosh::Director::TaskNotFound)
  end

  it "should cancel task" do
    test = Class.new(Bosh::Director::Jobs::BaseJob)
    task = Bosh::Director::Models::Task.make(:id => 1, :output => @task_dir,
                                             :state => "cancelling")

    test.perform(1)
    task.refresh
    task.state.should == "cancelled"
    Bosh::Director::Config.logger.should eql(@logger)
  end

  it "should cancel timeout-task" do
    test = Class.new(Bosh::Director::Jobs::BaseJob)
    task = Bosh::Director::Models::Task.make(:id => 1, :output => @task_dir,
                                             :state => "timeout")

    test.perform(1)
    task.refresh
    task.state.should == "cancelled"
    Bosh::Director::Config.logger.should eql(@logger)
  end

end
