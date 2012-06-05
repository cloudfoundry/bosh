# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::Jobs::FetchLogs do

  before(:each) do
    @deployment = Bosh::Director::Models::Deployment.make
    @blobstore = mock("blobstore")
    Bosh::Director::Config.stub!(:blobstore).and_return(@blobstore)

    @lock = mock("lock")
    @lock.stub!(:lock).and_yield
    Bosh::Director::Lock.stub!(:new).with("lock:deployment:#{@deployment.name}").and_return(@lock)
  end

  def make_job(instance_id)
    Bosh::Director::Jobs::FetchLogs.new(instance_id)
  end

  it "asks agent to fetch logs" do
    vm = Bosh::Director::Models::Vm.make(:deployment => @deployment, :agent_id => "agent-1", :cid => "vm-1")
    instance = Bosh::Director::Models::Instance.make(:deployment => @deployment, :vm => vm)

    job = make_job(instance.id)

    agent = mock("agent")
    Bosh::Director::AgentClient.stub!(:new).with("agent-1").and_return(agent)
    agent.should_receive(:fetch_logs).and_return("blobstore_id" => "blobstore-id")

    @lock.should_receive(:lock).and_yield
    job.perform.should == "blobstore-id"
  end

  it "fails if instance doesn't reference vm" do
    instance = Bosh::Director::Models::Instance.make(:deployment => @deployment, :vm => nil, :job => "zb", :index => "42")

    job = make_job(instance.id)

    lambda {
      job.perform
    }.should raise_error(BD::InstanceVmMissing,
                         "`zb/42' doesn't reference a VM")
  end

  it "keeps track of log bundles" do
    vm = Bosh::Director::Models::Vm.make(:deployment => @deployment, :agent_id => "agent-1", :cid => "vm-1")
    instance = Bosh::Director::Models::Instance.make(:deployment => @deployment, :vm => vm)
    job = make_job(instance.id)

    agent = mock("agent")
    Bosh::Director::AgentClient.stub!(:new).with("agent-1").and_return(agent)
    agent.should_receive(:fetch_logs).and_return("blobstore_id" => "deadbeef")

    @lock.should_receive(:lock).and_yield
    job.perform.should == "deadbeef"

    Bosh::Director::Models::LogBundle.count.should == 1
    Bosh::Director::Models::LogBundle.filter(:blobstore_id => "deadbeef").count.should == 1
  end

  it "cleans up old log bundles" do
    vm = Bosh::Director::Models::Vm.make(:deployment => @deployment, :agent_id => "agent-1", :cid => "vm-1")
    instance = Bosh::Director::Models::Instance.make(:deployment => @deployment, :vm => vm)
    job = make_job(instance.id)

    job.bundle_lifetime.should == 86400 * 10 # default lifetime
    job.bundle_lifetime = 0.01

    agent = mock("agent")
    Bosh::Director::AgentClient.stub!(:new).with("agent-1").and_return(agent)
    agent.should_receive(:fetch_logs).once.and_return("blobstore_id" => "deadbeef1")

    job.perform.should == "deadbeef1"
    Bosh::Director::Models::LogBundle.filter(:blobstore_id => "deadbeef1").count.should == 1

    agent.should_receive(:fetch_logs).once.and_return("blobstore_id" => "deadbeef2")
    @blobstore.should_receive(:delete).with("deadbeef1").and_return(true)

    sleep(0.05)
    job.perform.should == "deadbeef2"

    Bosh::Director::Models::LogBundle.filter(:blobstore_id => "deadbeef1").count.should == 0
    Bosh::Director::Models::LogBundle.filter(:blobstore_id => "deadbeef2").count.should == 1
  end

end
