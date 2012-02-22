# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::DrainManager do

  before(:all) do
    Bosh::Director::DrainManager.setup("thin")
  end

  before(:each) do
    Bosh::Director::DrainManager.draining = false
  end

  it "should shutdown on receiving drain message (no pending or running tasks)" do
    Bosh::Director::DrainManager.draining = true
    Bosh::Director::DrainManager.stub(:shutdown)
    Bosh::Director::DrainManager.should_receive(:shutdown)
    Bosh::Director::DrainManager.drain_and_shutdown
  end

  it "should ignore old tasks and shutdown on receiving drain message" do
    # Create a task
    task = Bosh::Director::Models::Task.make(:id => 1, :state => "queued")

    # Setup drain manager, it should ignore the above task
    Bosh::Director::DrainManager.setup("thin")
    Bosh::Director::DrainManager.draining = true
    Bosh::Director::DrainManager.stub(:shutdown)
    Bosh::Director::DrainManager.should_receive(:shutdown)
    Bosh::Director::DrainManager.drain_and_shutdown
  end

  def test_task(state)
    shutdown_called = false
    Bosh::Director::DrainManager.stub(:shutdown) { shutdown_called = true }

    task = Bosh::Director::Models::Task.make(:id => 1, :state => state)
    drain_thread = Bosh::Director::DrainManager.begin_draining

    # Make sure that shutdown isnt called
    drain_thread.run
    sleep 0.1
    shutdown_called.should be false

    # Make sure that shutdown gets called, once pending tasks finish
    task.state = "processed"
    task.save
    drain_thread.run
    drain_thread.join
    shutdown_called.should be true
  end

  it "should wait for currently running tasks to finish" do
    test_task("processing")
  end

  it "should wait for queued tasks to finish" do
    test_task("queued")
  end

  it "should fail to create new tasks when draining" do
    task = Bosh::Director::Models::Task.make(:id => 1, :state => "queued")
    drain_thread = Bosh::Director::DrainManager.begin_draining
    class SpecTask
      include Bosh::Director::Api::TaskHelper
    end
    spec_task = SpecTask.new
    lambda do
      spec_task.create_task("spec", "test task")
    end.should raise_exception(Bosh::Director::DrainInProgress)
  end

end
