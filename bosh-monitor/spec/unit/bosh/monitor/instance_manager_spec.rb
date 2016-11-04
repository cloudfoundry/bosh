require 'spec_helper'

describe Bhm::InstanceManager do
  let(:event_processor) { double(Bhm::EventProcessor) }
  let(:manager) { described_class.new(event_processor) }

  before do
    allow(event_processor).to receive(:process)
    allow(event_processor).to receive(:enable_pruning)
    allow(event_processor).to receive(:add_plugin)
  end

  context 'stubbed config' do

    before do
      Bhm.config = {"director" => {}}

      # Just use 2 loggers to test multiple agents without having to care
      # about stubbing delivery operations and providing well formed configs
      Bhm.plugins = [{"name" => "logger"}, {"name" => "logger"}]
      Bhm.intervals = OpenStruct.new(:agent_timeout => 10, :rogue_agent_alert => 10)
    end

    describe '#process_event' do
      context 'shutdown' do
        it 'shutdowns agent' do
          instance_1 = Bhm::Instance.create({'id' => 'iuuid1', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator'})
          instance_2 = Bhm::Instance.create({'id' => 'iuuid2', 'agent_id' => '008', 'index' => '0', 'job' => 'nats'})
          instance_3 = Bhm::Instance.create({'id' => 'iuuid3', 'agent_id' => '009', 'index' => '28', 'job' => 'mysql_node'})

          manager.sync_deployments([{'name' => 'mycloud'}])
          manager.sync_agents("mycloud", [instance_1, instance_2, instance_3])

          expect(manager.agents_count).to eq(3)
          expect(manager.analyze_agents).to eq(3)
          manager.process_event(:shutdown, "hm.agent.shutdown.008")
          expect(manager.agents_count).to eq(2)
          expect(manager.analyze_agents).to eq(2)
        end
      end

      context 'heartbeats' do
        it 'can process' do
          expect(manager.agents_count).to eq(0)
          manager.process_event(:heartbeat, "hm.agent.heartbeat.agent007")
          manager.process_event(:heartbeat, "hm.agent.heartbeat.agent007")
          manager.process_event(:heartbeat, "hm.agent.heartbeat.agent008")

          expect(manager.agents_count).to eq(2)
        end

        it 'processes a valid populated heartbeat message' do
          instance1 = {'id' => 'iuuid1', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator', 'expects_vm' => true}
          cloud1 = [instance1]
          manager.sync_deployments([{'name' => 'mycloud'}])
          manager.sync_deployment_state("mycloud", cloud1)

          expect(event_processor).to receive(:process).with(
            :heartbeat,
            {
              'timestamp' => Integer,
              'agent_id' => '007',
              'deployment' => 'mycloud',
              'node_id' => 'iuuid1',
              'job' => 'mutator'
            }
          )

          manager.process_event(:heartbeat, "hm.agent.heartbeat.007")
        end
      end

      context 'bad alert' do
        it 'does not increment alerts_processed' do
          expect(event_processor).to receive(:process).at_least(:once).and_raise(Bosh::Monitor::InvalidEvent)
          alert = Yajl::Encoder.encode({"id" => "778", "severity" => -2, "title" => nil, "summary" => "zbb", "created_at" => Time.now.utc.to_i})

          expect {
            manager.process_event(:alert, "hm.agent.alert.007", alert)
            manager.process_event(:alert, "hm.agent.alert.007", alert)
          }.to_not change(manager, :alerts_processed)
        end
      end

      context 'good alert' do
        it 'increments alerts_processed' do
          good_alert = Yajl::Encoder.encode({"id" => "778", "severity" => 2, "title" => "zb", "summary" => "zbb", "created_at" => Time.now.utc.to_i})

          expect {
            manager.process_event(:alert, "hm.agent.alert.007", good_alert)
            manager.process_event(:alert, "hm.agent.alert.007", good_alert)
          }.to change(manager, :alerts_processed).by(2)
        end
      end
    end

    describe '#sync_deployments' do

      it "can sync deployments" do
        deployment_1 = {'name' => 'deployment_1'}
        deployment_2 = {'name' => 'deployment_2'}
        manager.sync_deployments([deployment_1, deployment_2])

        expect(manager.deployments_count).to eq(2)

        manager.sync_deployments([deployment_1])
        expect(manager.deployments_count).to eq(1)
      end

      it "can sync deployments" do
        instance1 = {'id' => 'iuuid1', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator', 'expects_vm' => true}
        instance2 = {'id' => 'iuuid2', 'agent_id' => '008', 'index' => '1', 'job' => 'nats', 'expects_vm' => true}
        instance3 = {'id' => 'iuuid3', 'agent_id' => '009', 'index' => '2', 'job' => 'mysql_node', 'expects_vm' => true}
        instance4 = {'id' => 'iuuid4', 'agent_id' => '010', 'index' => '52', 'job' => 'zb', 'expects_vm' => true}

        cloud1 = [instance1, instance2]
        cloud2 = [instance3, instance4]
        manager.sync_deployments([{'name' => 'mycloud'}, {'name' => 'othercloud'}])
        manager.sync_deployment_state("mycloud", cloud1)
        manager.sync_deployment_state("othercloud", cloud2)

        expect(manager.deployments_count).to eq(2)
        expect(manager.agents_count).to eq(4)
        expect(manager.instances_count).to eq(4)

        manager.sync_deployments([{"name" => "mycloud"}]) # othercloud is gone
        manager.sync_deployment_state("mycloud", cloud1)
        expect(manager.deployments_count).to eq(1)
        expect(manager.agents_count).to eq(2)
        expect(manager.instances_count).to eq(2)
      end
    end

    describe '#sync_deployment_state' do
      it "can sync deployment state" do
        instance1 = {"id" => "007", 'agent_id' => '007', "index" => "0", "job" => "mutator", 'expects_vm' => true}
        instance2 = {"id" => "008", 'agent_id' => '008', "index" => "0", "job" => "nats", 'expects_vm' => true}
        instance3 = {"id" => "009", 'agent_id' => '009', "index" => "28", "job" => "mysql_node", 'expects_vm' => true}

        instances = [instance1, instance2]
        manager.sync_deployments([{'name' => 'mycloud'}])
        manager.sync_deployment_state("mycloud", instances)
        expect(manager.instances_count).to eq(2)
        expect(manager.agents_count).to eq(2)

        manager.sync_deployments([{'name' => 'mycloud'}])
        manager.sync_deployment_state("mycloud", instances - [instance1])
        expect(manager.instances_count).to eq(1)
        expect(manager.agents_count).to eq(1)

        manager.sync_deployments([{'name' => 'mycloud'}])
        manager.sync_deployment_state("mycloud", [instance1, instance3])
        expect(manager.instances_count).to eq(2)
        expect(manager.agents_count).to eq(2)
      end
    end

    describe '#get_agents_for_deployment' do
      it 'can provide agent information for a deployment' do
        instance_1 = Bhm::Instance.create({'id' => 'iuuid1', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator'})
        instance_2 = Bhm::Instance.create({'id' => 'iuuid2', 'agent_id' => '008', 'index' => '0', 'job' => 'nats'})
        instance_3 = Bhm::Instance.create({'id' => 'iuuid3', 'agent_id' => '009', 'index' => '28', 'job' => 'mysql_node'})

        manager.sync_deployments([{'name' => 'mycloud'}])
        manager.sync_agents("mycloud", [instance_1, instance_2, instance_3])

        agents = manager.get_agents_for_deployment('mycloud')
        expect(agents.size).to eq(3)
        agents['007'].deployment == 'mycloud'
        agents['007'].job == 'mutator'
        agents['007'].index == '0'
      end

      it 'can provide agent information for missing deployment' do
        agents = manager.get_agents_for_deployment('mycloud')

        expect(agents.size).to eq(0)
      end
    end


    describe '#get_instances_for_deployment' do
      before do
        manager.sync_deployments([{'name' => 'mycloud'}])
      end

      it 'returns deployment instances' do
        manager.sync_instances('mycloud', [{'id' => 'iuuid', 'job' => 'zb', 'index' => '0', 'expects_vm' => true}])

        expect(manager.get_instances_for_deployment('mycloud').size).to eq(1)
        manager.get_instances_for_deployment('mycloud').each do |instance|
          expect(instance).to be_a(Bhm::Instance)
        end
      end

      it 'returns an empty set if deployment has no instances' do
        expect(manager.get_instances_for_deployment('mycloud').size).to eq(0)
      end
    end

    describe '#analyze_agents' do

      before do
        manager.sync_deployments([{'name' => 'mycloud'}])
      end

      it 'can analyze agent' do
        manager.sync_agents('mycloud', [Bhm::Instance.create({'id' => 'iuuid3', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator'})])

        expect(manager.analyze_agents).to eq(1)
      end

      it 'alerts on a timed out agent' do
        manager.sync_agents('mycloud', [Bhm::Instance.create({'id' => 'some-sort-of-uuid', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator'})])

        ts = Time.now
        allow(Time).to receive(:now).and_return(ts + Bhm.intervals.agent_timeout + 10)

        expect(event_processor).to receive(:process).with(
            :alert,
            {
                severity: 2,
                source: 'mycloud: mutator(some-sort-of-uuid) [id=007, index=0, cid=]',
                title: '007 has timed out',
                created_at: anything,
                deployment: 'mycloud',
                job: 'mutator',
                instance_id: 'some-sort-of-uuid'
            }
        )

        manager.analyze_agents
      end

      it "can analyze all agents" do
        expect(manager.analyze_agents).to eq(0)

        # 3 regular agents
        instance_1 = Bhm::Instance.create({'id' => 'iuuid1', 'agent_id' => '007', 'index' => '0', 'job:' => 'mutator'})
        instance_2 = Bhm::Instance.create({'id' => 'iuuid2', 'agent_id' => '008', 'index' => '0', 'job:' => 'nats'})
        instance_3 = Bhm::Instance.create({'id' => 'iuuid3', 'agent_id' => '009', 'index' => '28', 'job' => 'mysql_node'})

        manager.sync_agents("mycloud", [instance_1, instance_2, instance_3])
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
      end
    end
  end

  describe '#analyze_instance' do

    before do
      manager.sync_deployments([{'name' => 'my_deployment'}])
    end

    it 'can analyze instance with vm' do
      instance = {'id' => 'instance-uuid', 'agent_id' => '007', 'index' => '0', 'cid' => 'cuuid', 'job' => 'mutator', 'expects_vm' => true}
      manager.sync_instances('my_deployment', [instance])

      expect(event_processor).to_not receive(:process)
      expect(manager.analyze_instance(Bhm::Instance.create(instance))).to be(true)
    end
  end

  describe '#analyze_instances' do

    before do
      manager.sync_deployments([{'name' => 'my_deployment'}])
    end

    it 'analyzes nothing for empty instances' do
      expect(event_processor).to_not receive(:process)
      expect(manager.analyze_instances).to eq(0)
    end

    it "can analyze all instances" do
      instance_data_1 = {'id' => 'iuuid2', 'agent_id' => '008', 'index' => '0', 'cid' => 'cuuid', 'job:' => 'nats', 'expects_vm' => true}
      instance_data_2 = {'id' => 'iuuid3', 'agent_id' => '009', 'index' => '28', 'cid' => 'cuuid', 'job' => 'mysql_node', 'expects_vm' => true}
      manager.sync_instances('my_deployment', [instance_data_1, instance_data_2])
      expect(event_processor).to_not receive(:process)

      expect(manager.analyze_instances).to eq(2)
    end

    it "alerts on an instance without VM" do
      instance = {'id' => 'instance-uuid', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator', 'expects_vm' => true}
      manager.sync_instances("my_deployment", [instance])
      expect(event_processor).to receive(:process).with(
          :alert,
          {
              severity: 2,
              source: 'my_deployment: mutator(instance-uuid) [agent_id=007, index=0, cid=]',
              title: 'instance-uuid has no VM',
              created_at: anything,
              deployment: 'my_deployment',
              job: 'mutator',
              instance_id: 'instance-uuid'
          }
      )

      expect(manager.analyze_instances).to eq(1)
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
      }.to raise_error(Bhm::PluginError, "Cannot find 'joes_plugin_thing' plugin")
    end
  end
end
