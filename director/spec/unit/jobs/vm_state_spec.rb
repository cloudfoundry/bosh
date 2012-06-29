# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::Jobs::VmState do

  before(:each) do
    @deployment = Bosh::Director::Models::Deployment.make
    @result_file = mock("result_file")
    Bosh::Director::Config.stub!(:result).and_return(@result_file)
  end

  it "parses agent info into vm_state" do
    vm = Bosh::Director::Models::Vm.make(:deployment => @deployment, :agent_id => "agent-1", :cid => "vm-1")
    agent = mock("agent")
    Bosh::Director::AgentClient.stub!(:new).with("agent-1").and_return(agent)
    agent_state = { "vm_cid" => "vm-1",
                    "networks" => {"test" => {"ip" => "1.1.1.1"}},
                    "agent_id" => "agent-1",
                    "job_state" => "running",
                    "resource_pool" => {"name" => "test_resource_pool" }}
    agent.should_receive(:get_state).and_return(agent_state)

    @result_file.should_receive(:write).with do |agent_status|
      status = JSON.parse(agent_status)
      status["ips"].should == ["1.1.1.1"]
      status["vm_cid"].should == "vm-1"
      status["agent_id"].should == "agent-1"
      status["job_state"].should == "running"
      status["resource_pool"].should == "test_resource_pool"
    end

    job = Bosh::Director::Jobs::VmState.new(@deployment.id)
    job.perform
  end

  it "should handle unresponsive agents" do
    vm = Bosh::Director::Models::Vm.make(:deployment => @deployment, :agent_id => "agent-1", :cid => "vm-1")
    agent = mock("agent")
    Bosh::Director::AgentClient.stub!(:new).with("agent-1").and_return(agent)
    agent.should_receive(:get_state).and_raise(Bosh::Director::RpcTimeout)

    @result_file.should_receive(:write).with do |agent_status|
      status = JSON.parse(agent_status)
      status["vm_cid"].should == "vm-1"
      status["agent_id"].should == "agent-1"
      status["job_state"].should == "unresponsive agent"
    end

    job = Bosh::Director::Jobs::VmState.new(@deployment.id)
    job.perform
  end
end

