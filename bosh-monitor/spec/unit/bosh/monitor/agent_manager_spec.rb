require 'spec_helper'

describe Bhm::AgentManager do
  let(:event_processor) { double(Bhm::EventProcessor) }
  let(:manager) { described_class.new(event_processor) }

  before do
    allow(event_processor).to receive(:process)
    allow(event_processor).to receive(:enable_pruning)
    allow(event_processor).to receive(:add_plugin)
  end

  context "stubbed config" do

    before do
      Bhm.config = {"director" => {}}

      # Just use 2 loggers to test multiple agents without having to care
      # about stubbing delivery operations and providing well formed configs
      Bhm.plugins = [{"name" => "logger"}, {"name" => "logger"}]
      Bhm.intervals = OpenStruct.new(:agent_timeout => 10, :rogue_agent_alert => 10)
    end

    it "can process heartbeats" do
      expect(manager.agents_count).to eq(0)
      manager.process_event(:heartbeat, "hm.agent.heartbeat.agent007")
      manager.process_event(:heartbeat, "hm.agent.heartbeat.agent007")
      manager.process_event(:heartbeat, "hm.agent.heartbeat.agent008")

      expect(manager.agents_count).to eq(2)
    end

    it "increments alerts_processed on good alerts" do
      good_alert = Yajl::Encoder.encode({"id" => "778", "severity" => 2, "title" => "zb", "summary" => "zbb", "created_at" => Time.now.utc.to_i})

      expect {
        manager.process_event(:alert, "hm.agent.alert.007", good_alert)
        manager.process_event(:alert, "hm.agent.alert.007", good_alert)
      }.to change(manager, :alerts_processed).by(2)
    end

    it "does not increment alerts_processed on bad alerts" do
      expect(event_processor).to receive(:process).at_least(:once).and_raise(Bosh::Monitor::InvalidEvent)
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

      expect(manager.agents_count).to eq(3)
      expect(manager.analyze_agents).to eq(3)
      manager.process_event(:shutdown, "hm.agent.shutdown.008")
      expect(manager.agents_count).to eq(2)
      expect(manager.analyze_agents).to eq(2)
    end

    it "can start managing agent" do
      expect(manager.add_agent("mycloud", {"agent_id" => "007", "job" => "zb", "index" => "0"})).to be(true)
      expect(manager.agents_count).to eq(1)
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

      expect(manager.deployments_count).to eq(2)
      expect(manager.agents_count).to eq(4)

      manager.sync_deployments([{"name" => "mycloud"}]) # othercloud is gone
      expect(manager.agents_count).to eq(2)
    end

    it "can sync agents" do
      vm1 = {"agent_id" => "007", "index" => "0", "job" => "mutator"}
      vm2 = {"agent_id" => "008", "index" => "0", "job" => "nats"}
      vm3 = {"agent_id" => "009", "index" => "28", "job" => "mysql_node"}

      vms = [vm1, vm2]
      manager.sync_agents("mycloud", vms)
      expect(manager.agents_count).to eq(2)

      manager.sync_agents("mycloud", vms - [vm1])
      expect(manager.agents_count).to eq(1)

      manager.sync_agents("mycloud", [vm1, vm3])
      expect(manager.agents_count).to eq(2)
    end

    it "can provide agent information for a deployment" do
      manager.add_agent("mycloud", {"agent_id" => "007", "index" => "0", "job" => "mutator"})
      manager.add_agent("mycloud", {"agent_id" => "008", "index" => "0", "job" => "nats"})
      manager.add_agent("mycloud", {"agent_id" => "009", "index" => "28", "job" => "mysql_node"})

      agents = manager.get_agents_for_deployment("mycloud")
      expect(agents.size).to eq(3)
      agents["007"].deployment == "mycloud"
      agents["007"].job == "mutator"
      agents["007"].index == "0"
    end

    it "refuses to register agents with malformed director vm data" do
      expect(manager.add_agent("mycloud", {"job" => "zb", "index" => "0"})).to be(false) # no agent_id
      expect(manager.add_agent("mycloud", ["zb"])).to be(false) # not a Hash
    end

    it "can analyze agent" do
      expect(manager.analyze_agent("007")).to be(false) # No such agent yet
      manager.add_agent("mycloud", {"agent_id" => "007", "index" => "0", "job" => "mutator"})
      expect(manager.analyze_agent("007")).to be(true)
    end

    it "can analyze all agents" do
      expect(manager.analyze_agents).to eq(0)

      # 3 regular agents
      manager.add_agent("mycloud", {"agent_id" => "007", "index" => "0", "job" => "mutator"})
      manager.add_agent("mycloud", {"agent_id" => "008", "index" => "0", "job" => "nats"})
      manager.add_agent("mycloud", {"agent_id" => "009", "index" => "28", "job" => "mysql_node"})
      expect(manager.analyze_agents).to eq(3)

      alert = Yajl::Encoder.encode({"id" => "778", "severity" => 2, "title" => "zb", "summary" => "zbb", "created_at" => Time.now.utc.to_i})

      # Alert for already managed agent
      manager.process_event(:alert, "hm.agent.alert.007", alert)
      expect(manager.analyze_agents).to eq(3)

      # Alert for non managed agent
      manager.process_event(:alert, "hm.agent.alert.256", alert)
      expect(manager.analyze_agents).to eq(4)

      manager.process_event(:heartbeat, "256", nil) # Heartbeat from managed agent
      manager.process_event(:heartbeat, "512", nil) # Heartbeat from unmanaged agent

      expect(manager.analyze_agents).to eq(5)

      ts = Time.now
      allow(Time).to receive(:now).and_return(ts + [Bhm.intervals.agent_timeout, Bhm.intervals.rogue_agent_alert].max + 10)

      manager.process_event(:heartbeat, "512", nil)
      # 5 agents total:  2 timed out, 1 rogue, 1 rogue AND timeout, expecting 4 alerts
      expect(event_processor).to receive(:process).with(:alert, anything).exactly(4).times
      expect(manager.analyze_agents).to eq(5)
      expect(manager.agents_count).to eq(4)

      # Now previously removed "256" gets reported as a good citizen
      # 5 agents total, 3 timed out, 1 rogue
      manager.add_agent("mycloud", {"agent_id" => "256", "index" => "0", "job" => "redis_node"})
      expect(event_processor).to receive(:process).with(:alert, anything).exactly(4).times
      expect(manager.analyze_agents).to eq(5)
    end
  end

  context "real config" do
    let(:mock_nats) { double('nats') }

    before do
      Bhm::config=Psych.load_file(sample_config)
      allow(mock_nats).to receive(:subscribe)
      allow(Bhm).to receive(:nats).and_return(mock_nats)
      allow(EM).to receive(:schedule).and_yield
    end

    it "has the cloudwatch plugin" do
      expect(Bhm::Plugins::CloudWatch).to receive(:new).with(
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
