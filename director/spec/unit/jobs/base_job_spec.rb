require File.dirname(__FILE__) + '/../../spec_helper'

describe Bosh::Director::Jobs::BaseJob do

  it "should set up the task" do
    test = Class.new do
      extend(Bosh::Director::Jobs::BaseJob)
      define_method :perform do
        5
      end
    end

    logger = Logger.new(nil)
    Logger.stub!(:new).with("/some/path").and_return(logger)

    task = stub("task")
    task.should_receive(:output).and_return("/some/path")

    task.should_receive(:state=).with(:processing)
    task.should_receive(:timestamp=)
    task.should_receive(:save!)

    task.should_receive(:state=).with(:done)
    task.should_receive(:result=).with(5)
    task.should_receive(:timestamp=)
    task.should_receive(:save!)

    Bosh::Director::Models::Task.stub!(:[]).with(1).and_return(task)

    test.perform(1)

    Bosh::Director::Config.logger.should eql(logger)
  end

  it "should pass on the rest of the arguments to the actual job" do
    test = Class.new do
      extend(Bosh::Director::Jobs::BaseJob)
      define_method :initialize do |*args|
        @args = args
      end

      define_method :perform do
        @args
      end
    end

    logger = Logger.new(nil)
    Logger.stub!(:new).with("/some/path").and_return(logger)

    task = stub("task")
    task.should_receive(:output).and_return("/some/path")

    task.should_receive(:state=).with(:processing)
    task.should_receive(:timestamp=)
    task.should_receive(:save!)

    task.should_receive(:state=).with(:done)
    task.should_receive(:result=).with(["a", [:b], {:c => 5}])
    task.should_receive(:timestamp=)
    task.should_receive(:save!)

    Bosh::Director::Models::Task.stub!(:[]).with(1).and_return(task)

    test.perform(1, "a", [:b], {:c => 5})
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

    task = stub("task")
    task.should_receive(:output).and_return("/some/path")

    task.should_receive(:state=).with(:processing)
    task.should_receive(:timestamp=)
    task.should_receive(:save!)

    task.should_receive(:state=).with(:error)
    task.should_receive(:result=).with("test")
    task.should_receive(:timestamp=)
    task.should_receive(:save!)

    Bosh::Director::Models::Task.stub!(:[]).with(1).and_return(task)

    test.perform(1)
  end

  it "should raise an exception when the task was not found" do
    test = Class.new do
      extend(Bosh::Director::Jobs::BaseJob)
      define_method :perform do
        raise "test"
      end
    end

    Bosh::Director::Models::Task.stub!(:[]).with(1).and_return(nil)
    lambda { test.perform(1) }.should raise_exception(Bosh::Director::TaskNotFound)
  end

end