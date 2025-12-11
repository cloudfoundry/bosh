require 'spec_helper'

module Bosh::Monitor
  describe InstanceManager do
    let(:event_processor) { double(Bosh::Monitor::EventProcessor) }
    let(:manager) { described_class.new(event_processor) }

    before do
      allow(event_processor).to receive(:process)
      allow(event_processor).to receive(:enable_pruning)
      allow(event_processor).to receive(:add_plugin)
    end

    context 'stubbed config' do
      before do
        Bosh::Monitor.config = { 'director' => {} }

        # Just use 2 loggers to test multiple agents without having to care
        # about stubbing delivery operations and providing well formed configs
        Bosh::Monitor.plugins = [{ 'name' => 'logger' }, { 'name' => 'logger' }]
        Bosh::Monitor.intervals = OpenStruct.new(agent_timeout: 10, rogue_agent_alert: 10)
      end

      describe '#process_event' do
        context 'shutdown' do
          it 'shutdowns agent' do
            instance_1 = Bosh::Monitor::Instance.create('id' => 'iuuid1', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator')
            instance_2 = Bosh::Monitor::Instance.create('id' => 'iuuid2', 'agent_id' => '008', 'index' => '0', 'job' => 'nats')
            instance_3 = Bosh::Monitor::Instance.create('id' => 'iuuid3', 'agent_id' => '009', 'index' => '28', 'job' => 'mysql_node')

            manager.sync_deployments([{ 'name' => 'mycloud' }])
            manager.sync_agents('mycloud', [instance_1, instance_2, instance_3])

            expect(manager.agents_count).to eq(3)
            expect(manager.analyze_agents).to eq(3)
            manager.process_event(:shutdown, 'hm.agent.shutdown.008')
            expect(manager.agents_count).to eq(2)
            expect(manager.analyze_agents).to eq(2)
          end
        end

        context 'heartbeats' do
          it 'can process' do
            expect(manager.agents_count).to eq(0)
            manager.process_event(:heartbeat, 'hm.agent.heartbeat.agent007')
            manager.process_event(:heartbeat, 'hm.agent.heartbeat.agent007')
            manager.process_event(:heartbeat, 'hm.agent.heartbeat.agent008')

            expect(manager.agents_count).to eq(2)
          end

          it 'processes a valid populated heartbeat message' do
            instance1 = { 'id' => 'iuuid1', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator', 'expects_vm' => true }
            cloud1 = [instance1]
            manager.sync_deployments([{ 'name' => 'mycloud', 'teams' => ['ateam'] }])
            manager.sync_deployment_state({ 'name' => 'mycloud', 'teams' => ['ateam'] }, cloud1)

            expect(event_processor).to receive(:process).with(
              :heartbeat,
              { 'timestamp' => an_instance_of(Integer),
                'agent_id' => '007',
                'deployment' => 'mycloud',
                'instance_id' => 'iuuid1',
                'job' => 'mutator',
                'teams' => ['ateam'], }
            )

            manager.process_event(:heartbeat, 'hm.agent.heartbeat.007')
          end

          context 'when heartbeat information cannot be completed for instance_id, job, or deployment' do
            it 'does not process the heartbeat' do
              expect(event_processor).not_to receive(:process)

              manager.process_event(:heartbeat, 'hm.agent.heartbeat.007')
            end
          end

          context 'when teams have changed between heartbeats' do
            it 'updates teams in heartbeat event' do
              instance1 = { 'id' => 'iuuid1', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator', 'expects_vm' => true }
              cloud1 = [instance1]
              manager.sync_deployments([{ 'name' => 'mycloud', 'teams' => ['ateam'] }])
              manager.sync_deployment_state({ 'name' => 'mycloud', 'teams' => ['ateam'] }, cloud1)

              expect(event_processor).to receive(:process).with(
                :heartbeat,
                { 'timestamp' => an_instance_of(Integer),
                  'agent_id' => '007',
                  'deployment' => 'mycloud',
                  'instance_id' => 'iuuid1',
                  'job' => 'mutator',
                  'teams' => ['ateam'], }
              )

              manager.process_event(:heartbeat, 'hm.agent.heartbeat.007')

              manager.sync_deployment_state({ 'name' => 'mycloud', 'teams' => %w[ateam bteam] }, cloud1)

              expect(event_processor).to receive(:process).with(
                :heartbeat,
                { 'timestamp' => an_instance_of(Integer),
                  'agent_id' => '007',
                  'deployment' => 'mycloud',
                  'instance_id' => 'iuuid1',
                  'job' => 'mutator',
                  'teams' => %w[ateam bteam], }
              )

              manager.process_event(:heartbeat, 'hm.agent.heartbeat.007')
            end
          end
        end

        context 'bad alert' do
          it 'does not increment alerts_processed' do
            expect(event_processor).to receive(:process).at_least(:once).and_raise(Bosh::Monitor::InvalidEvent)
            alert = JSON.dump('id' => '778', 'severity' => -2, 'title' => nil, 'summary' => 'zbb', 'created_at' => Time.now.utc.to_i)

            expect do
              manager.process_event(:alert, 'hm.agent.alert.007', alert)
              manager.process_event(:alert, 'hm.agent.alert.007', alert)
            end.to_not change(manager, :alerts_processed)
          end
        end

        context 'good alert' do
          it 'increments alerts_processed' do
            good_alert = JSON.dump('id' => '778', 'severity' => 2, 'title' => 'zb', 'summary' => 'zbb', 'created_at' => Time.now.utc.to_i)

            expect do
              manager.process_event(:alert, 'hm.agent.alert.007', good_alert)
              manager.process_event(:alert, 'hm.agent.alert.007', good_alert)
            end.to change(manager, :alerts_processed).by(2)
          end
        end
      end

      describe '#sync_deployments' do
        it 'can sync deployments' do
          deployment_1 = { 'name' => 'deployment_1' }
          deployment_2 = { 'name' => 'deployment_2' }
          manager.sync_deployments([deployment_1, deployment_2])

          expect(manager.deployments_count).to eq(2)

          manager.sync_deployments([deployment_1])
          expect(manager.deployments_count).to eq(1)
        end

        it 'can sync deployments' do
          instance1 = { 'id' => 'iuuid1', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator', 'expects_vm' => true }
          instance2 = { 'id' => 'iuuid2', 'agent_id' => '008', 'index' => '1', 'job' => 'nats', 'expects_vm' => true }
          instance3 = { 'id' => 'iuuid3', 'agent_id' => '009', 'index' => '2', 'job' => 'mysql_node', 'expects_vm' => true }
          instance4 = { 'id' => 'iuuid4', 'agent_id' => '010', 'index' => '52', 'job' => 'zb', 'expects_vm' => true }

          cloud1 = [instance1, instance2]
          cloud2 = [instance3, instance4]
          manager.sync_deployments([{ 'name' => 'mycloud' }, { 'name' => 'othercloud' }])
          manager.sync_deployment_state({ 'name' => 'mycloud' }, cloud1)
          manager.sync_deployment_state({ 'name' => 'othercloud' }, cloud2)

          expect(manager.deployments_count).to eq(2)
          expect(manager.agents_count).to eq(4)
          expect(manager.instances_count).to eq(4)

          manager.sync_deployments([{ 'name' => 'mycloud' }]) # othercloud is gone
          manager.sync_deployment_state({ 'name' => 'mycloud' }, cloud1)
          expect(manager.deployments_count).to eq(1)
          expect(manager.agents_count).to eq(2)
          expect(manager.instances_count).to eq(2)
        end
      end

      describe '#sync_deployment_state' do
        it 'can sync deployment state' do
          instance1 = { 'id' => '007', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator', 'expects_vm' => true }
          instance2 = { 'id' => '008', 'agent_id' => '008', 'index' => '0', 'job' => 'nats', 'expects_vm' => true }
          instance3 = { 'id' => '009', 'agent_id' => '009', 'index' => '28', 'job' => 'mysql_node', 'expects_vm' => true }

          instances = [instance1, instance2]
          manager.sync_deployments([{ 'name' => 'mycloud' }])
          manager.sync_deployment_state({ 'name' => 'mycloud' }, instances)
          expect(manager.instances_count).to eq(2)
          expect(manager.agents_count).to eq(2)

          manager.sync_deployments([{ 'name' => 'mycloud' }])
          manager.sync_deployment_state({ 'name' => 'mycloud' }, instances - [instance1])
          expect(manager.instances_count).to eq(1)
          expect(manager.agents_count).to eq(1)

          manager.sync_deployments([{ 'name' => 'mycloud' }])
          manager.sync_deployment_state({ 'name' => 'mycloud' }, [instance1, instance3])
          expect(manager.instances_count).to eq(2)
          expect(manager.agents_count).to eq(2)
        end
      end

      describe '#get_agents_for_deployment' do
        it 'can provide agent information for a deployment' do
          instance_1 = Bosh::Monitor::Instance.create('id' => 'iuuid1', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator')
          instance_2 = Bosh::Monitor::Instance.create('id' => 'iuuid2', 'agent_id' => '008', 'index' => '0', 'job' => 'nats')
          instance_3 = Bosh::Monitor::Instance.create('id' => 'iuuid3', 'agent_id' => '009', 'index' => '28', 'job' => 'mysql_node')

          manager.sync_deployments([{ 'name' => 'mycloud' }])
          manager.sync_agents('mycloud', [instance_1, instance_2, instance_3])

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

      describe '#get_deleted_agents_for_deployment' do
        it 'can provide agent information for a deployment' do
          instance_1 = Bosh::Monitor::Instance.create('id' => 'iuuid1',  'index' => '0', 'job' => 'mutator', 'expects_vm' => true)
          instance_2 = Bosh::Monitor::Instance.create('id' => 'iuuid2',  'index' => '0', 'job' => 'nats', 'expects_vm' => true)
          instance_3 = Bosh::Monitor::Instance.create('id' => 'iuuid3',  'index' => '28', 'job' => 'mysql_node', 'expects_vm' => true)

          manager.sync_deployments([{ 'name' => 'mycloud' }])
          manager.sync_agents('mycloud', [instance_1, instance_2, instance_3])

          agents = manager.get_deleted_agents_for_deployment('mycloud')
          expect(agents.size).to eq(3)
          agents['iuuid3'].deployment == 'mycloud'
          agents['iuuid3'].job == 'mutator'
          agents['iuuid3'].index == '28'
        end

        it 'can provide agent information for missing deployment' do
          agents = manager.get_deleted_agents_for_deployment('mycloud')

          expect(agents.size).to eq(0)
        end
      end

      describe '#get_instances_for_deployment' do
        before do
          manager.sync_deployments([{ 'name' => 'mycloud' }])
        end

        it 'returns deployment instances' do
          manager.sync_instances('mycloud', [{ 'id' => 'iuuid', 'job' => 'zb', 'index' => '0', 'expects_vm' => true }])

          expect(manager.get_instances_for_deployment('mycloud').size).to eq(1)
          manager.get_instances_for_deployment('mycloud').each do |instance|
            expect(instance).to be_a(Bosh::Monitor::Instance)
          end
        end

        it 'returns an empty set if deployment has no instances' do
          expect(manager.get_instances_for_deployment('mycloud').size).to eq(0)
        end
      end

      describe '#unresponsive_agents' do
        it 'can return number of unresponsive agents for each deployment' do
          instance1 = Bosh::Monitor::Instance.create('id' => 'iuuid1', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator')
          instance2 = Bosh::Monitor::Instance.create('id' => 'iuuid2', 'agent_id' => '008', 'index' => '0', 'job' => 'nats')
          instance3 = Bosh::Monitor::Instance.create('id' => 'iuuid3', 'agent_id' => '009', 'index' => '28', 'job' => 'mysql_node')

          manager.sync_deployments([{ 'name' => 'mycloud' }])
          manager.sync_agents('mycloud', [instance1, instance2, instance3])

          expect(manager.unresponsive_agents).to eq('mycloud' => 0)
          ts = Time.now
          allow(Time).to receive(:now).and_return(ts + Bosh::Monitor.intervals.agent_timeout + 10)
          expect(manager.unresponsive_agents).to eq("mycloud" => 3)
        end
      end

      describe "#unhealthy_agents" do
        it "can return number of unhealthy agents (job_state == 'running' AND number_of_processes == 0) for each deployment" do
          instance1 = Bosh::Monitor::Instance.create("id" => "iuuid1", "agent_id" => "007", "index" => "0", "job" => "mutator")
          instance2 = Bosh::Monitor::Instance.create("id" => "iuuid2", "agent_id" => "008", "index" => "0", "job" => "nats")
          instance3 = Bosh::Monitor::Instance.create("id" => "iuuid3", "agent_id" => "009", "index" => "28", "job" => "mysql_node")

          manager.sync_deployments([{ "name" => "mycloud" }])
          manager.sync_agents("mycloud", [instance1, instance2, instance3])

          # Initially all agents are healthy
          expect(manager.unhealthy_agents).to eq("mycloud" => 0)

          # Set agent job_state == 'running' and number_of_processes == 0 (unhealthy)
          agent1 = manager.get_agents_for_deployment("mycloud")["007"]
          agent1.job_state = "running"
          agent1.number_of_processes = 0
          expect(manager.unhealthy_agents).to eq("mycloud" => 1)

          # Set another agent to same state
          agent2 = manager.get_agents_for_deployment("mycloud")["008"]
          agent2.job_state = "running"
          agent2.number_of_processes = 0
          expect(manager.unhealthy_agents).to eq("mycloud" => 2)

          # Agent with job_state != 'running' should not count as unhealthy
          agent3 = manager.get_agents_for_deployment("mycloud")["009"]
          agent3.job_state = "stopped"
          agent3.number_of_processes = 0
          expect(manager.unhealthy_agents).to eq("mycloud" => 2)

          # Agent with number_of_processes > 0 should not count as unhealthy even if job_state == 'running'
          agent1.number_of_processes = 5
          expect(manager.unhealthy_agents).to eq("mycloud" => 1)
        end
      end

      describe '#total_available_agents' do
        it 'counts all agents for each deployment and includes unmanaged agents' do
          instance1 = Bosh::Monitor::Instance.create('id' => 'iuuid1', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator')
          instance2 = Bosh::Monitor::Instance.create('id' => 'iuuid2', 'agent_id' => '008', 'index' => '0', 'job' => 'nats')

          manager.sync_deployments([{ 'name' => 'mycloud' }])
          manager.sync_agents('mycloud', [instance1, instance2])

          # Initially both agents are present
          expect(manager.total_available_agents).to include('mycloud' => 2)

          # Add an unmanaged (rogue) agent via heartbeat processing
          manager.process_event(:heartbeat, 'hm.agent.heartbeat.unmanaged-1')
          expect(manager.total_available_agents['unmanaged']).to eq(1)

          # Simulate timed out agents -- they should still be counted as part of the deployment total
          ts = Time.now
          allow(Time).to receive(:now).and_return(ts + Bosh::Monitor.intervals.agent_timeout + 100)
          expect(manager.unresponsive_agents['mycloud']).to eq(2)
          expect(manager.total_available_agents).to include('mycloud' => 2)
        end
      end

      describe '#failing_instances' do
        it 'counts agents with job_state == failing for each deployment' do
          instance1 = Bosh::Monitor::Instance.create('id' => 'iuuid1', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator')
          instance2 = Bosh::Monitor::Instance.create('id' => 'iuuid2', 'agent_id' => '008', 'index' => '0', 'job' => 'nats')

          manager.sync_deployments([{ 'name' => 'mycloud' }])
          manager.sync_agents('mycloud', [instance1, instance2])

          # Initially none are failing
          expect(manager.failing_instances).to eq('mycloud' => 0)

          agent1 = manager.get_agents_for_deployment('mycloud')['007']
          agent1.job_state = 'failing'

          expect(manager.failing_instances).to eq('mycloud' => 1)
        end
      end

      describe '#stopped_instances' do
        it 'counts agents with job_state == stopped for each deployment' do
          instance1 = Bosh::Monitor::Instance.create('id' => 'iuuid1', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator')
          instance2 = Bosh::Monitor::Instance.create('id' => 'iuuid2', 'agent_id' => '008', 'index' => '0', 'job' => 'nats')

          manager.sync_deployments([{ 'name' => 'mycloud' }])
          manager.sync_agents('mycloud', [instance1, instance2])

          # Initially none are stopped
          expect(manager.stopped_instances).to eq('mycloud' => 0)

          agent2 = manager.get_agents_for_deployment('mycloud')['008']
          agent2.job_state = 'stopped'

          expect(manager.stopped_instances).to eq('mycloud' => 1)
        end
      end

      describe '#unknown_instances' do
        it 'counts agents with unknown (nil) job_state for each deployment' do
          instance1 = Bosh::Monitor::Instance.create('id' => 'iuuid1', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator')
          instance2 = Bosh::Monitor::Instance.create('id' => 'iuuid2', 'agent_id' => '008', 'index' => '0', 'job' => 'nats')

          manager.sync_deployments([{ 'name' => 'mycloud' }])
          manager.sync_agents('mycloud', [instance1, instance2])

          # Ensure both have a defined state first
          manager.get_agents_for_deployment('mycloud').each_value { |a| a.job_state = 'running' }
          expect(manager.unknown_instances).to eq('mycloud' => 0)

          # Set one to unknown
          agent1 = manager.get_agents_for_deployment('mycloud')['007']
          agent1.job_state = nil

          expect(manager.unknown_instances).to eq('mycloud' => 1)
        end
      end

      describe '#analyze_agents' do
        let(:instance_1) { Bosh::Monitor::Instance.create('id' => 'instance-uuid-1', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator') }
        let(:instance_2) { Bosh::Monitor::Instance.create('id' => 'instance-uuid-2', 'agent_id' => '008', 'index' => '1', 'job' => 'mutator') }
        let(:instance_3) { Bosh::Monitor::Instance.create('id' => 'instance-uuid-3', 'agent_id' => '009', 'index' => '2', 'job' => 'mutator2') }

        before do
          manager.sync_deployments([{ 'name' => 'mycloud' }])
        end

        it 'can analyze agent' do
          manager.sync_agents('mycloud', [instance_1])

          expect(manager.analyze_agents).to eq(1)
        end

        context('when multiple agents time out in different deployments') do
          let(:instance_4) { Bosh::Monitor::Instance.create('id' => 'instance-uuid-4', 'agent_id' => '010', 'index' => '3', 'job' => 'mutator2') }

          before do
            manager.sync_deployments([{ 'name' => 'mycloud' }, { 'name' => 'mycloud-2' }])
            manager.sync_agents('mycloud', [instance_1, instance_2, instance_3])
            manager.sync_agents('mycloud-2', [instance_4])
            ts = Time.now
            allow(Time).to receive(:now).and_return(ts + Bosh::Monitor.intervals.agent_timeout + 10)
          end

          it 'sends an alert for each timed out agent' do
            expect(event_processor).to receive(:process).with(
              :alert,
              hash_including(category: 'vm_health'),
            ).exactly(4).times

            manager.analyze_agents
          end

          it 'sends an aggregated alert per deployment' do
            expect(event_processor).to receive(:process).with(
              :alert,
              severity: 2,
              category: 'deployment_health',
              source: 'mycloud',
              title: 'mycloud has instances with timed out agents',
              created_at: anything,
              deployment: 'mycloud',
              jobs_to_instance_ids: { 'mutator' => %w[instance-uuid-1 instance-uuid-2],
                                      'mutator2' => ['instance-uuid-3'] },
            )
            expect(event_processor).to receive(:process).with(
              :alert,
              severity: 2,
              category: 'deployment_health',
              source: 'mycloud-2',
              title: 'mycloud-2 has instances with timed out agents',
              created_at: anything,
              deployment: 'mycloud-2',
              jobs_to_instance_ids: { 'mutator2' => ['instance-uuid-4'] },
            )
            manager.analyze_agents
          end
        end

        context 'when the deployment is locked' do
          before do
            manager.sync_deployment_state({ 'name' => 'mycloud', 'locked' => true }, [instance_1])
            manager.sync_agents('mycloud', [instance_1])
          end

          it 'does not analyze agents for that deployment' do
            expect(manager.analyze_agents).to eq(0)
          end
        end

        it 'alerts on a timed out agent' do
          manager.sync_agents('mycloud', [instance_1])
          ts = Time.now
          allow(Time).to receive(:now).and_return(ts + Bosh::Monitor.intervals.agent_timeout + 10)

          expect(event_processor).to receive(:process).with(
            :alert,
            severity: 2,
            category: 'vm_health',
            source: 'mycloud: mutator(instance-uuid-1) [id=007, index=0, cid=]',
            title: '007 has timed out',
            created_at: anything,
            deployment: 'mycloud',
            job: 'mutator',
            instance_id: 'instance-uuid-1',
          )

          manager.analyze_agents
        end

        it 'can analyze all agents' do
          expect(manager.analyze_agents).to eq(0)

          manager.sync_agents('mycloud', [instance_1, instance_2, instance_3])
          expect(manager.analyze_agents).to eq(3)

          alert = JSON.dump('id' => '778', 'severity' => 2, 'title' => 'zb', 'summary' => 'zbb', 'created_at' => Time.now.utc.to_i)

          # Alert for already managed agent
          manager.process_event(:alert, 'hm.agent.alert.007', alert)
          expect(manager.analyze_agents).to eq(3)

          # Alert for non managed agent
          manager.process_event(:alert, 'hm.agent.alert.256', alert)
          expect(manager.analyze_agents).to eq(4)

          manager.process_event(:heartbeat, '256', nil) # Heartbeat from managed agent
          manager.process_event(:heartbeat, '512', nil) # Heartbeat from unmanaged agent

          expect(manager.analyze_agents).to eq(5)

          ts = Time.now
          allow(Time).to receive(:now).and_return(ts + [Bosh::Monitor.intervals.agent_timeout, Bosh::Monitor.intervals.rogue_agent_alert].max + 10)

          manager.process_event(:heartbeat, '512', nil)
          # 5 agents total:  2 timed out, 1 rogue, 1 rogue AND timeout, expecting 4 alerts
          expect(event_processor).to receive(:process).with(:alert, anything).exactly(5).times
          expect(manager.analyze_agents).to eq(5)
          expect(manager.agents_count).to eq(4)
        end
      end
    end

    describe '#alert_needed?' do
      before do
        manager.sync_deployments([{ 'name' => 'my_deployment' }])
      end

      it 'can analyze instance with vm' do
        instance = { 'id' => 'instance-uuid', 'agent_id' => '007', 'index' => '0', 'cid' => 'cuuid', 'job' => 'mutator', 'expects_vm' => true }

        expect(manager.alert_needed?(Bosh::Monitor::Instance.create(instance))).to be(false)
      end

      context 'when the instances expects a VM, and does not have one' do
        it 'sends an alert' do
          instance = { 'id' => 'instance-uuid', 'agent_id' => '007', 'index' => '0', 'cid' => nil, 'job' => 'mutator', 'expects_vm' => true }

          expect(manager.alert_needed?(Bosh::Monitor::Instance.create(instance))).to be(true)
        end
      end
    end

    describe '#analyze_instances' do
      let(:instance_1) { { 'id' => 'instance-uuid-1', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator', 'expects_vm' => true } }
      let(:instance_2) { { 'id' => 'instance-uuid-2', 'agent_id' => '008', 'index' => '1', 'job' => 'mutator', 'expects_vm' => true } }

      before do
        manager.sync_deployments([{ 'name' => 'my_deployment' }])
      end

      it 'analyzes nothing for empty instances' do
        expect(event_processor).to_not receive(:process)
        expect(manager.analyze_instances).to eq(0)
      end

      context 'instances with vms' do
        before do
          instance_1['cid'] = 'cuuid'
          instance_2['cid'] = 'cuuid'
        end

        it 'can analyze all instances' do
          manager.sync_instances('my_deployment', [instance_1, instance_2])
          expect(event_processor).to_not receive(:process)

          expect(manager.analyze_instances).to eq(2)
        end
      end

      context 'when the deployment is locked' do
        before do
          instance_1['cid'] = 'cuuid'
          instance_2['cid'] = 'cuuid'
        end

        it 'can analyze all instances' do
          manager.sync_deployment_state({ 'name' => 'my_deployment', 'locked' => true }, [instance_1])
          manager.sync_instances('my_deployment', [instance_1, instance_2])
          expect(event_processor).to_not receive(:process)

          expect(manager.analyze_instances).to eq(0)
        end
      end

      it 'alerts on an instance without VM' do
        manager.sync_instances('my_deployment', [instance_1])
        expect(event_processor).to receive(:process).with(
          :alert,
          severity: 2,
          category: 'vm_health',
          source: 'my_deployment: mutator(instance-uuid-1) [agent_id=007, index=0, cid=]',
          title: 'instance-uuid-1 has no VM',
          created_at: anything,
          deployment: 'my_deployment',
          job: 'mutator',
          instance_id: 'instance-uuid-1',
        )

        expect(manager.analyze_instances).to eq(1)
      end

      context('when instances have no vm in different deployments') do
        let(:instance_3) { { 'id' => 'instance-uuid-3', 'agent_id' => '009', 'index' => '2', 'job' => 'mutator2', 'expects_vm' => true } }
        let(:instance_4) { { 'id' => 'instance-uuid-4', 'agent_id' => '010', 'index' => '3', 'job' => 'mutator2', 'expects_vm' => true } }

        before do
          manager.sync_deployments([{ 'name' => 'mycloud' }, { 'name' => 'mycloud-2' }])
          manager.sync_instances('mycloud', [instance_1, instance_2, instance_3])
          manager.sync_instances('mycloud-2', [instance_4])
        end

        it 'sends an alert for each instance with missing vm' do
          expect(event_processor).to receive(:process).with(
            :alert,
            hash_including(category: 'vm_health'),
          ).exactly(4).times

          manager.analyze_instances
        end

        it 'sends an aggregated alert per deployment' do
          expect(event_processor).to receive(:process).with(
            :alert,
            severity: 2,
            category: 'deployment_health',
            source: 'mycloud',
            title: 'mycloud has instances which do not have VMs',
            created_at: anything,
            deployment: 'mycloud',
            jobs_to_instance_ids: { 'mutator' => %w[instance-uuid-1 instance-uuid-2],
                                    'mutator2' => ['instance-uuid-3'] },
          )
          expect(event_processor).to receive(:process).with(
            :alert,
            severity: 2,
            category: 'deployment_health',
            source: 'mycloud-2',
            title: 'mycloud-2 has instances which do not have VMs',
            created_at: anything,
            deployment: 'mycloud-2',
            jobs_to_instance_ids: { 'mutator2' => ['instance-uuid-4'] },
          )
          manager.analyze_instances
        end
      end
    end

    context 'real config' do
      let(:mock_nats) { double('nats') }

      before do
        Bosh::Monitor.config = YAML.load_file(sample_config,  permitted_classes: [Symbol], permitted_symbols:[], aliases: true)
        allow(mock_nats).to receive(:subscribe)
        allow(Bosh::Monitor).to receive(:nats).and_return(mock_nats)
      end

      it 'has the tsdb plugin' do
        expect(Bosh::Monitor::Plugins::Tsdb).to receive(:new).with({
          'host' => 'localhost',
          'port' => 4242,
        }).and_call_original

        manager.setup_events
      end
    end

    context 'when loading plugin not found' do
      before do
        config = YAML.load_file(sample_config,  permitted_classes: [Symbol], permitted_symbols:[], aliases: true)
        config['plugins'] << { 'name' => 'joes_plugin_thing', 'events' => %w[alerts heartbeats] }
        Bosh::Monitor.config = config
      end

      it 'raises an error' do
        expect do
          manager.setup_events
        end.to raise_error(Bosh::Monitor::PluginError, "Cannot find 'joes_plugin_thing' plugin")
      end
    end
  end
end
