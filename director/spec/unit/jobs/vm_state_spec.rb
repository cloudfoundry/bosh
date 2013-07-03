# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::Jobs::VmState do

  before(:each) do
    @deployment = BD::Models::Deployment.make
    @result_file = mock("result_file")
    BD::Config.stub!(:result).and_return(@result_file)
    BD::Config.stub!(:dns_domain_name).and_return("microbosh")    
  end

  describe 'described_class.job_type' do
    it 'returns a symbol representing job type' do
      expect(described_class.job_type).to eq(:vms)
    end
  end

  it "parses agent info into vm_state" do
    BDM::Vm.make(:deployment => @deployment,
                 :agent_id => "agent-1", :cid => "vm-1")
    agent = mock("agent")
    BD::AgentClient.stub!(:new).with("agent-1", :timeout => 5).and_return(agent)
    agent_state = { "vm_cid" => "vm-1",
                    "networks" => {"test" => {"ip" => "1.1.1.1"}},
                    "agent_id" => "agent-1",
                    "job_state" => "running",
                    "resource_pool" => {"name" => "test_resource_pool" }}
    agent.should_receive(:get_state).and_return(agent_state)

    @result_file.should_receive(:write).with do |agent_status|
      status = JSON.parse(agent_status)
      status["ips"].should == ["1.1.1.1"]
      status["dns"].should be_empty
      status["vm_cid"].should == "vm-1"
      status["agent_id"].should == "agent-1"
      status["job_state"].should == "running"
      status["resource_pool"].should == "test_resource_pool"
      status["vitals"].should be_nil
    end

    job = BD::Jobs::VmState.new(@deployment.id, nil)
    job.perform
  end

  it "parses agent info into vm_state with vitals" do
    BDM::Vm.make(:deployment => @deployment,
                 :agent_id => "agent-1", :cid => "vm-1")
    agent = mock("agent")
    BD::AgentClient.stub!(:new).with("agent-1", :timeout => 5).and_return(agent)

    agent_state = { "vm_cid" => "vm-1",
                    "networks" => {"test" => {"ip" => "1.1.1.1"}},
                    "agent_id" => "agent-1",
                    "job_state" => "running",
                    "resource_pool" => {"name" => "test_resource_pool" },
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
    agent.should_receive(:get_state).and_return(agent_state)

    @result_file.should_receive(:write).with do |agent_status|
      status = JSON.parse(agent_status)
      status["ips"].should == ["1.1.1.1"]
      status["dns"].should be_empty
      status["vm_cid"].should == "vm-1"
      status["agent_id"].should == "agent-1"
      status["job_state"].should == "running"
      status["resource_pool"].should == "test_resource_pool"
      status["vitals"]["load"].should == ["1", "5", "15"]
      status["vitals"]["cpu"].should == {"user" => "u", "sys" => "s", "wait"=>"w"}
      status["vitals"]["mem"].should == {"percent" => "p", "kb" => "k"}
      status["vitals"]["swap"].should == {"percent" => "p", "kb" => "k"}
      status["vitals"]["disk"].should == {"system" => {"percent" => "p"},
                                          "ephemeral" => {"percent" => "p"}}
    end

    job = BD::Jobs::VmState.new(@deployment.id, "full")
    job.perform
  end

  it "should return DNS A records if they exist" do
    BDM::Vm.make(:deployment => @deployment, :agent_id => "agent-1", :cid => "vm-1")
    domain = BD::Models::Dns::Domain.make(:name => "microbosh", :type => "NATIVE")
    BD::Models::Dns::Record.make(:domain => domain, :name => "index.job.network.deployment.microbosh",
                                 :type => "A", :content => "1.1.1.1", :ttl => 14400)
    agent = mock("agent")
    BD::AgentClient.stub!(:new).with("agent-1", :timeout => 5).and_return(agent)
    agent_state = { "vm_cid" => "vm-1",
                    "networks" => {"test" => {"ip" => "1.1.1.1"}},
                    "agent_id" => "agent-1",
                    "job_state" => "running",
                    "resource_pool" => {"name" => "test_resource_pool" }}
    agent.should_receive(:get_state).and_return(agent_state)

    @result_file.should_receive(:write).with do |agent_status|
      status = JSON.parse(agent_status)
      status["ips"].should == ["1.1.1.1"]
      status["dns"].should == ["index.job.network.deployment.microbosh"]
      status["vm_cid"].should == "vm-1"
      status["agent_id"].should == "agent-1"
      status["job_state"].should == "running"
      status["resource_pool"].should == "test_resource_pool"
      status["vitals"].should be_nil
    end

    job = BD::Jobs::VmState.new(@deployment.id, nil)
    job.perform
  end

  it "should handle unresponsive agents" do
    BDM::Vm.make(:deployment => @deployment, :agent_id => "agent-1",
                 :cid => "vm-1")
    agent = mock("agent")
    BD::AgentClient.stub!(:new).with("agent-1", :timeout => 5).and_return(agent)
    agent.should_receive(:get_state).and_raise(BD::RpcTimeout)

    @result_file.should_receive(:write).with do |agent_status|
      status = JSON.parse(agent_status)
      status["vm_cid"].should == "vm-1"
      status["agent_id"].should == "agent-1"
      status["job_state"].should == "unresponsive agent"
      status['resurrection_paused'].should be_nil
    end

    job = BD::Jobs::VmState.new(@deployment.id, nil)
    job.perform
  end

  it 'should get the resurrection paused status' do
    BD::Models::Instance.create(deployment: @deployment, job: "dea", index: "0", state: 'started', resurrection_paused: true)
    BDM::Vm.make(:deployment => @deployment,
                 :agent_id => "agent-1", :cid => "vm-1")
    agent = mock("agent")
    BD::AgentClient.stub!(:new).with("agent-1", :timeout => 5).and_return(agent)

    agent_state = { "vm_cid" => "vm-1",
                    "networks" => {"test" => {"ip" => "1.1.1.1"}},
                    "agent_id" => "agent-1",
                    "index" => 0,
                    "job" => {"name" => "dea"},
                    "job_state" => "running",
                    "resource_pool" => {"name" => "test_resource_pool" },
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
    agent.should_receive(:get_state).and_return(agent_state)

    job = BD::Jobs::VmState.new(@deployment.id, "full")

    @result_file.should_receive(:write).with do |agent_status|
      status = JSON.parse(agent_status)
      expect(status['resurrection_paused']).to be_true
    end
    job.perform
  end

end

