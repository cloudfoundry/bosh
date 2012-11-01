# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::Jobs::VmVitals do

  before(:each) do
    @deployment = Bosh::Director::Models::Deployment.make
    @result_file = mock("result_file")
    Bosh::Director::Config.stub!(:result).and_return(@result_file)
  end

  it "parses agent vitals into vm_vitals" do
    vm = Bosh::Director::Models::Vm.make(:deployment => @deployment, :agent_id => "agent-1", :cid => "vm-1")
    agent = mock("agent")
    Bosh::Director::AgentClient.stub!(:new).with("agent-1").and_return(agent)
    agent_vitals = { "vm_cid" => "vm-1",
                     "agent_id" => "agent-1",
                     "job_state" => "running",
                     "vitals" => {
                       "load"=> ["1", "5", "15"],
                       "cpu"=> {"user" => "u", "sys" => "s", "wait" => "w"},
                       "mem"=> {"percent" => "p", "kb" => "k"},
                       "swap"=> {"percent" => "p", "kb" => "k"},
                       "disk"=> {"system" => {"percent" => "p"},
                                 "ephemeral" => {"percent" => "p"}
                                }
                     }
                  }
    agent.should_receive(:vitals).and_return(agent_vitals)

    @result_file.should_receive(:write).with do |vitals|
      status = JSON.parse(vitals)
      status["vm_cid"].should == "vm-1"
      status["agent_id"].should == "agent-1"
      status["job_state"].should == "running"
      status["vitals"]["load"].should == ["1", "5", "15"]
      status["vitals"]["cpu"].should == {"user" => "u", "sys" => "s",
                                         "wait"=>"w"}
      status["vitals"]["mem"].should == {"percent" => "p", "kb" => "k"}
      status["vitals"]["swap"].should == {"percent" => "p", "kb" => "k"}
      status["vitals"]["disk"].should == {"system" => {"percent" => "p"},
                                          "ephemeral" => {"percent" => "p"}}
    end

    job = Bosh::Director::Jobs::VmVitals.new(@deployment.id)
    job.perform
  end

  it "should handle unresponsive agents" do
    vm = Bosh::Director::Models::Vm.make(:deployment => @deployment, :agent_id => "agent-1", :cid => "vm-1")
    agent = mock("agent")
    Bosh::Director::AgentClient.stub!(:new).with("agent-1").and_return(agent)
    agent.should_receive(:vitals).and_raise(Bosh::Director::RpcTimeout)

    @result_file.should_receive(:write).with do |vitals|
      status = JSON.parse(vitals)
      status["vm_cid"].should == "vm-1"
      status["agent_id"].should == "agent-1"
      status["job_state"].should == "unresponsive agent"
    end

    job = Bosh::Director::Jobs::VmVitals.new(@deployment.id)
    job.perform
  end
end