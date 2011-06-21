require File.dirname(__FILE__) + '/../../spec_helper'

describe Bosh::Director::Jobs::BaseJob do

  before(:all) do
    @event_log = Bosh::Director::EventLog.new(1, nil)
  end

  it "should set up the task" do
    test = Class.new do
      extend(Bosh::Director::Jobs::BaseJob)
      define_method :perform do
        5
      end
    end

    task = Bosh::Director::Models::Task.make(:id => 1, :output => "/some/path")

    logger = Logger.new(nil)
    Logger.stub!(:new).with("/some/path").and_return(logger)
    Bosh::Director::EventLog.stub!(:new).and_return(@event_log)
    test.perform(1)

    task.refresh
    task.state.should == "done"
    task.result.should == "5"

    Bosh::Director::Config.logger.should eql(logger)
  end

  it "should pass on the rest of the arguments to the actual job" do
    test = Class.new do
      extend(Bosh::Director::Jobs::BaseJob)
      define_method :initialize do |*args|
        @args = args
      end

      define_method :perform do
        Yajl::Encoder.encode(@args)
      end
    end

    logger = Logger.new(nil)
    Logger.stub!(:new).with("/some/path").and_return(logger)
    Bosh::Director::EventLog.stub!(:new).and_return(@event_log)

    task = Bosh::Director::Models::Task.make(:id => 1, :output => "/some/path")

    test.perform(1, "a", [:b], {:c => 5})

    task.refresh
    task.state.should == "done"
    Yajl::Parser.parse(task.result).should == ["a", ["b"], {"c" => 5}]
  end

  it "should record the error when there is an exception" do
    test = Class.new do
      extend(Bosh::Director::Jobs::BaseJob)
      define_method :perform do
        raise "test"
      end
    end

    logger = Logger.new(nil)
    Logger.stub!(:new).with("/some/path").and_return(logger)
    Bosh::Director::EventLog.stub!(:new).and_return(@event_log)

    task = Bosh::Director::Models::Task.make(:id => 1, :output => "/some/path")

    test.perform(1)

    task.refresh
    task.state.should == "error"
    task.result.should == "test"
  end

  it "should raise an exception when the task was not found" do
    test = Class.new do
      extend(Bosh::Director::Jobs::BaseJob)
      define_method :perform do
        fail
      end
    end

    lambda { test.perform(1) }.should raise_exception(Bosh::Director::TaskNotFound)
  end

end
