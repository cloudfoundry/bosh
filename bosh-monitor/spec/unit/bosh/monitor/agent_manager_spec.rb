require 'spec_helper'

describe Bhm::AgentManager do
  let(:event_processor) { double(Bhm::EventProcessor) }
  let(:manager) { described_class.new(event_processor) }

  before do
    event_processor.stub(:process)
    event_processor.stub(:enable_pruning)
    event_processor.stub(:add_plugin)
  end

  context "stubbed config" do

    before :each do
      Bhm.logger = Logging::logger(StringIO.new)

      # Just use 2 loggers to test multiple agents without having to care
      # about stubbing delivery operations and providing well formed configs
      Bhm.plugins = [{"name" => "logger"}, {"name" => "logger"}]
      Bhm.intervals = OpenStruct.new(:agent_timeout => 10, :rogue_agent_alert => 10)
    end

    it "can process heartbeats" do
      manager.agents_count.should == 0
      manager.process_event(:heartbeat, "hm.agent.heartbeat.agent007")
      manager.process_event(:heartbeat, "hm.agent.heartbeat.agent007")
      manager.process_event(:heartbeat, "hm.agent.heartbeat.agent008")

      manager.agents_count.should == 2
    end

    it "increments alerts_processed on good alerts" do
      good_alert = Yajl::Encoder.encode({"id" => "778", "severity" => 2, "title" => "zb", "summary" => "zbb", "created_at" => Time.now.utc.to_i})

      expect {
        manager.process_event(:alert, "hm.agent.alert.007", good_alert)
        manager.process_event(:alert, "hm.agent.alert.007", good_alert)
      }.to change(manager, :alerts_processed).by(2)
    end

    it "does not increment alerts_processed on bad alerts" do
      event_processor.should_receive(:process).at_least(:once).and_raise(Bosh::Monitor::InvalidEvent)
      alert = Yajl::Encoder.encode({"id" => "778", "severity" => -2, "title" => nil, "summary" => "zbb", "created_at" => Time.now.utc.to_i})

      expect {
        manager.process_event(:alert, "hm.agent.alert.007", alert)
        manager.process_event(:alert, "hm.agent.alert.007", alert)
      }.to_not change(manager, :alerts_processed)
    end

    it "can process agent shutdowns" do
      manager.add_agent("mycloud", {"agent_id" => "007", "index" => "0", "job" => "mutator"})
      manager.add_agent("mycloud", {"agent_id" => "008", "index" => "0", "job" => "nats"})
      manager.add_agent("mycloud", {"agent_id" => "009", "index" => "28", "job" => "mysql_node"})

      manager.agents_count.should == 3
      manager.analyze_agents.should == 3
      manager.process_event(:shutdown, "hm.agent.shutdown.008")
      manager.agents_count.should == 2
      manager.analyze_agents.should == 2
    end

    it "can start managing agent" do
      manager.add_agent("mycloud", {"agent_id" => "007", "job" => "zb", "index" => "0"}).should be(true)
      manager.agents_count.should == 1
    end

    it "can sync deployments" do
      vm1 = {"agent_id" => "007", "index" => "0", "job" => "mutator"}
      vm2 = {"agent_id" => "008", "index" => "0", "job" => "nats"}
      vm3 = {"agent_id" => "009", "index" => "28", "job" => "mysql_node"}
      vm4 = {"agent_id" => "010", "index" => "52", "job" => "zb"}

      cloud1 = [vm1, vm2]
      cloud2 = [vm3, vm4]
      manager.sync_agents("mycloud", cloud1)
      manager.sync_agents("othercloud", cloud2)

      manager.deployments_count.should == 2
      manager.agents_count.should == 4

      manager.sync_deployments([{"name" => "mycloud"}]) # othercloud is gone
      manager.agents_count.should == 2
    end

    it "can sync agents" do
      vm1 = {"agent_id" => "007", "index" => "0", "job" => "mutator"}
      vm2 = {"agent_id" => "008", "index" => "0", "job" => "nats"}
      vm3 = {"agent_id" => "009", "index" => "28", "job" => "mysql_node"}

      vms = [vm1, vm2]
      manager.sync_agents("mycloud", vms)
      manager.agents_count.should == 2

      manager.sync_agents("mycloud", vms - [vm1])
      manager.agents_count.should == 1

      manager.sync_agents("mycloud", [vm1, vm3])
      manager.agents_count.should == 2
    end

    it "can provide agent information for a deployment" do
      manager.add_agent("mycloud", {"agent_id" => "007", "index" => "0", "job" => "mutator"})
      manager.add_agent("mycloud", {"agent_id" => "008", "index" => "0", "job" => "nats"})
      manager.add_agent("mycloud", {"agent_id" => "009", "index" => "28", "job" => "mysql_node"})

      agents = manager.get_agents_for_deployment("mycloud")
      agents.size.should == 3
      agents["007"].deployment == "mycloud"
      agents["007"].job == "mutator"
      agents["007"].index == "0"
    end

    it "refuses to register agents with malformed director vm data" do
      manager.add_agent("mycloud", {"job" => "zb", "index" => "0"}).should be(false) # no agent_id
      manager.add_agent("mycloud", ["zb"]).should be(false) # not a Hash
    end

    it "can analyze agent" do
      manager.analyze_agent("007").should be(false) # No such agent yet
      manager.add_agent("mycloud", {"agent_id" => "007", "index" => "0", "job" => "mutator"})
      manager.analyze_agent("007").should be(true)
    end

    it "can analyze all agents" do
      manager.analyze_agents.should == 0

      # 3 regular agents
      manager.add_agent("mycloud", {"agent_id" => "007", "index" => "0", "job" => "mutator"})
      manager.add_agent("mycloud", {"agent_id" => "008", "index" => "0", "job" => "nats"})
      manager.add_agent("mycloud", {"agent_id" => "009", "index" => "28", "job" => "mysql_node"})
      manager.analyze_agents.should == 3

      alert = Yajl::Encoder.encode({"id" => "778", "severity" => 2, "title" => "zb", "summary" => "zbb", "created_at" => Time.now.utc.to_i})

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
      Time.stub(:now).and_return(ts + [Bhm.intervals.agent_timeout, Bhm.intervals.rogue_agent_alert].max + 10)

      manager.process_event(:heartbeat, "512", nil)
      # 5 agents total:  2 timed out, 1 rogue, 1 rogue AND timeout, expecting 4 alerts
      event_processor.should_receive(:process).with(:alert, anything).exactly(4).times
      manager.analyze_agents.should == 5
      manager.agents_count.should == 4

      # Now previously removed "256" gets reported as a good citizen
      # 5 agents total, 3 timed out, 1 rogue
      manager.add_agent("mycloud", {"agent_id" => "256", "index" => "0", "job" => "redis_node"})
      event_processor.should_receive(:process).with(:alert, anything).exactly(4).times
      manager.analyze_agents.should == 5
    end
  end

  context "real config" do
    let(:mock_nats) { double('nats') }

    before do
      Bhm::config=Psych.load_file(sample_config)
      mock_nats.stub(:subscribe)
      Bhm.stub(:nats).and_return(mock_nats)
    end

    it "has the cloudwatch plugin" do
      Bhm::Plugins::CloudWatch.should_receive(:new).with(
          {
              'access_key_id' => 'access_key',
              'secret_access_key' => 'secret_access_key'
          }
      ).and_call_original

      manager.setup_events
    end
  end

  context "when loading plugin not found" do
    before do
      config = Psych.load_file(sample_config)
      config["plugins"] << { "name" => "joes_plugin_thing", "events" => ["alerts", "heartbeats"] }
      Bhm::config = config
    end

    it "raises an error" do
      expect {
        manager.setup_events
      }.to raise_error(Bhm::PluginError, "Cannot find `joes_plugin_thing' plugin")
    end
  end
end
