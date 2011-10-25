require 'spec_helper'

describe Bhm::AgentManager do

  before :each do
    Bhm.logger = Logging::logger(StringIO.new)

    # Just use 2 loggers to test multiple agents without having to care
    # about stubbing delivery operations and providing well formed configs
    Bhm.plugins = [ { "name" => "logger" }, { "name" => "logger" } ]
    Bhm.intervals = OpenStruct.new(:agent_timeout => 10, :rogue_agent_alert => 10)
  end

  def make_manager
    Bhm::AgentManager.new
  end

  it "can process heartbeats" do
    manager = make_manager
    manager.agents_count.should == 0
    manager.process_event(:heartbeat, "hm.agent.heartbeat.agent007")
    manager.process_event(:heartbeat, "hm.agent.heartbeat.agent007")
    manager.process_event(:heartbeat, "hm.agent.heartbeat.agent008")

    manager.agents_count.should == 2
  end

  it "can process alerts" do
    manager = make_manager

    good_alert = Yajl::Encoder.encode({"id" => "778", "severity" => 2, "title" => "zb", "summary" => "zbb", "created_at" => Time.now.utc.to_i })
    bad_alert = Yajl::Encoder.encode({"id" => "778", "severity" => -2, "title" => nil, "summary" => "zbb", "created_at" => Time.now.utc.to_i })
    malformed_alert = Yajl::Encoder.encode("zb")

    manager.process_event(:alert, "hm.agent.alert.007", good_alert)
    manager.process_event(:alert, "hm.agent.alert.007", bad_alert)
    manager.process_event(:alert, "hm.agent.alert.007", malformed_alert)

    manager.alerts_processed.should == 1
  end

  it "can process agent shutdowns" do
    manager = make_manager
    manager.add_agent("mycloud", { "agent_id" => "007", "index" => "0", "job" => "mutator"})
    manager.add_agent("mycloud", { "agent_id" => "008", "index" => "0", "job" => "nats"})
    manager.add_agent("mycloud", { "agent_id" => "009", "index" => "28", "job" => "mysql_node"})

    manager.agents_count.should == 3
    manager.analyze_agents.should == 3
    manager.process_event(:shutdown, "hm.agent.shutdown.008")
    manager.agents_count.should == 2
    manager.analyze_agents.should == 2
  end

  it "can start managing agent" do
    manager = make_manager

    manager.add_agent("mycloud", {"agent_id" => "007", "job" => "zb", "index" => "0"}).should be_true
    manager.agents_count.should == 1
  end

  it "can sync deployments" do
    manager = make_manager
    vm1 = { "agent_id" => "007", "index" => "0", "job" => "mutator"}
    vm2 = { "agent_id" => "008", "index" => "0", "job" => "nats"}
    vm3 = { "agent_id" => "009", "index" => "28", "job" => "mysql_node"}
    vm4 = { "agent_id" => "010", "index" => "52", "job" => "zb"}

    cloud1 = [ vm1, vm2 ]
    cloud2 = [ vm3, vm4 ]
    manager.sync_agents("mycloud", cloud1)
    manager.sync_agents("othercloud", cloud2)

    manager.deployments_count.should == 2
    manager.agents_count.should == 4

    manager.sync_deployments([ { "name" => "mycloud" }]) # othercloud is gone
    manager.agents_count.should == 2
  end

  it "can sync agents" do
    manager = make_manager
    vm1 = { "agent_id" => "007", "index" => "0", "job" => "mutator"}
    vm2 = { "agent_id" => "008", "index" => "0", "job" => "nats"}
    vm3 = { "agent_id" => "009", "index" => "28", "job" => "mysql_node"}

    vms = [ vm1, vm2 ]
    manager.sync_agents("mycloud", vms)
    manager.agents_count.should == 2

    manager.sync_agents("mycloud", vms - [vm1])
    manager.agents_count.should == 1

    manager.sync_agents("mycloud", [vm1, vm3])
    manager.agents_count.should == 2
  end

  it "refuses to register agents with malformed director vm data" do
    manager = make_manager

    manager.add_agent("mycloud", {"job" => "zb", "index" => "0"}).should be_false # no agent_id
    manager.add_agent("mycloud", ["zb"]).should be_false # not a Hash
  end

  it "can analyze agent" do
    manager = make_manager

    manager.analyze_agent("007").should be_false # No such agent yet
    manager.add_agent("mycloud", { "agent_id" => "007", "index" => "0", "job" => "mutator"})
    manager.analyze_agent("007").should be_true
  end

  it "can analyze all agents" do
    processor = Bhm::EventProcessor.new
    manager = make_manager
    manager.processor = processor

    manager.analyze_agents.should == 0

    # 3 regular agents
    manager.add_agent("mycloud", { "agent_id" => "007", "index" => "0", "job" => "mutator"})
    manager.add_agent("mycloud", { "agent_id" => "008", "index" => "0", "job" => "nats"})
    manager.add_agent("mycloud", { "agent_id" => "009", "index" => "28", "job" => "mysql_node"})
    manager.analyze_agents.should == 3

    alert = Yajl::Encoder.encode({"id" => "778", "severity" => 2, "title" => "zb", "summary" => "zbb", "created_at" => Time.now.utc.to_i })

    # Alert for already managed agent
    manager.process_event(:alert, "hm.agent.alert.007", alert)
    manager.analyze_agents.should == 3

    # Alert for non managed agent
    manager.process_event(:alert, "hm.agent.alert.256", alert)
    manager.analyze_agents.should == 4

    manager.process_event(:heartbeat, "256", nil) # Heartbeat from managed agent
    manager.process_event(:heartbeat, "512", nil) # Heartbeat from unmanaged agent

    manager.analyze_agents.should == 5

    ts = Time.now
    Time.stub!(:now).and_return(ts + [ Bhm.intervals.agent_timeout, Bhm.intervals.rogue_agent_alert ].max + 10)

    manager.process_event(:heartbeat, "512", nil)
    # 5 agents total:  2 timed out, 1 rogue, 1 rogue AND timeout, expecting 4 alerts
    processor.should_receive(:process).with(:alert, anything).exactly(4).times
    manager.analyze_agents.should == 5
    manager.agents_count.should == 4

    # Now previously removed "256" gets reported as a good citizen
    # 5 agents total, 3 timed out, 1 rogue
    manager.add_agent("mycloud", { "agent_id" => "256", "index" => "0", "job" => "redis_node" })
    processor.should_receive(:process).with(:alert, anything).exactly(4).times
    manager.analyze_agents.should == 5
  end

end
