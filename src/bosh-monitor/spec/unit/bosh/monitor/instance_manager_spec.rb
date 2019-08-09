require 'spec_helper'

module Bhm
  describe InstanceManager do
    let(:event_processor) { double(Bhm::EventProcessor) }
    let(:manager) { described_class.new(event_processor) }

    before do
      allow(event_processor).to receive(:process)
      allow(event_processor).to receive(:enable_pruning)
      allow(event_processor).to receive(:add_plugin)
    end

    context 'stubbed config' do
      before do
        Bhm.config = { 'director' => {} }

        # Just use 2 loggers to test multiple agents without having to care
        # about stubbing delivery operations and providing well formed configs
        Bhm.plugins = [{ 'name' => 'logger' }, { 'name' => 'logger' }]
        Bhm.intervals = OpenStruct.new(agent_timeout: 10, rogue_agent_alert: 30, vm_start_timeout: 60)
      end

      describe '#process_event' do
        context 'shutdown' do
          it 'shutdowns agent' do
            instance1 = { 'id' => 'iuuid1', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator' }
            instance2 = { 'id' => 'iuuid2', 'agent_id' => '008', 'index' => '0', 'job' => 'nats' }
            instance3 = { 'id' => 'iuuid3', 'agent_id' => '009', 'index' => '28', 'job' => 'mysql_node' }

            manager.sync_deployments([{ 'name' => 'mycloud' }])
            manager.sync_deployment_state({ 'name' => 'mycloud' }, [instance1, instance2, instance3])

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
              'timestamp' => Integer,
              'agent_id' => '007',
              'deployment' => 'mycloud',
              'instance_id' => 'iuuid1',
              'job' => 'mutator',
              'teams' => ['ateam'],
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
                'timestamp' => Integer,
                'agent_id' => '007',
                'deployment' => 'mycloud',
                'instance_id' => 'iuuid1',
                'job' => 'mutator',
                'teams' => ['ateam'],
              )

              manager.process_event(:heartbeat, 'hm.agent.heartbeat.007')

              manager.sync_deployment_state({ 'name' => 'mycloud', 'teams' => %w[ateam bteam] }, cloud1)

              expect(event_processor).to receive(:process).with(
                :heartbeat,
                'timestamp' => Integer,
                'agent_id' => '007',
                'deployment' => 'mycloud',
                'instance_id' => 'iuuid1',
                'job' => 'mutator',
                'teams' => %w[ateam bteam],
              )

              manager.process_event(:heartbeat, 'hm.agent.heartbeat.007')
            end
          end
        end

        context 'bad alert' do
          it 'does not increment alerts_processed' do
            expect(event_processor).to receive(:process).at_least(:once).and_raise(Bosh::Monitor::InvalidEvent)
            alert = JSON.dump('id' => '778', 'severity' => -2, 'title' => nil, 'summary' => 'zbb',
                              'created_at' => Time.now.utc.to_i)

            expect do
              manager.process_event(:alert, 'hm.agent.alert.007', alert)
              manager.process_event(:alert, 'hm.agent.alert.007', alert)
            end.to_not change(manager, :alerts_processed)
          end
        end

        context 'good alert' do
          it 'increments alerts_processed' do
            good_alert = JSON.dump('id' => '778', 'severity' => 2, 'title' => 'zb', 'summary' => 'zbb',
                                   'created_at' => Time.now.utc.to_i)

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

        context 'vm detaches' do
          it 'removes agent' do
            instances = [{ 'id' => '007', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator', 'expects_vm' => true }]
            manager.sync_deployments([{ 'name' => 'mycloud' }])
            manager.sync_deployment_state({ 'name' => 'mycloud' }, instances)

            ts = Time.now
            allow(Time).to receive(:now).and_return(ts + Bhm.intervals.agent_timeout + 10)
            instances = [{ 'id' => '007', 'agent_id' => nil, 'index' => '0', 'job' => 'mutator', 'expects_vm' => false }]
            manager.sync_deployment_state({ 'name' => 'mycloud' }, instances)

            expect(manager.instances_count).to eq(1)
            expect(manager.agents_count).to eq(0)
            agents = manager.get_agents_for_deployment('mycloud')
            expect(agents.key?('007')).to eq(false)
            instances = manager.get_instances_for_deployment('mycloud')
            expect(instances[0].id).to eq('007')
            expect(instances[0].agent_id).to be_nil

            expect(event_processor).to_not receive(:process)
            manager.analyze_agents
          end
        end

        context 'vm attaches' do
          it 'adds agent' do
            instances = [{ 'id' => '007', 'agent_id' => nil, 'index' => '0', 'job' => 'mutator', 'expects_vm' => false }]
            manager.sync_deployments([{ 'name' => 'mycloud' }])
            manager.sync_deployment_state({ 'name' => 'mycloud' }, instances)

            ts = Time.now
            allow(Time).to receive(:now).and_return(ts + Bhm.intervals.agent_timeout + 10)
            instances = [{ 'id' => '007', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator', 'expects_vm' => true }]
            manager.sync_deployment_state({ 'name' => 'mycloud' }, instances)

            expect(manager.instances_count).to eq(1)
            expect(manager.agents_count).to eq(1)
            agents = manager.get_agents_for_deployment('mycloud')
            expect(agents.key?('007')).to eq(true)
            instances = manager.get_instances_for_deployment('mycloud')
            expect(instances[0].id).to eq('007')
            expect(instances[0].agent_id).to eq('007')

            expect(event_processor).to_not receive(:process)
            manager.analyze_agents
          end
        end

        context 'vm reattaches' do
          it 'updates agent' do
            instances = [{ 'id' => '007', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator', 'expects_vm' => true }]
            manager.sync_deployments([{ 'name' => 'mycloud' }])
            manager.sync_deployment_state({ 'name' => 'mycloud' }, instances)

            ts = Time.now
            allow(Time).to receive(:now).and_return(ts + Bhm.intervals.agent_timeout + 10)
            instances = [{ 'id' => '007', 'agent_id' => '008', 'index' => '0', 'job' => 'mutator', 'expects_vm' => true }]
            manager.sync_deployment_state({ 'name' => 'mycloud' }, instances)

            expect(manager.instances_count).to eq(1)
            expect(manager.agents_count).to eq(1)
            agents = manager.get_agents_for_deployment('mycloud')
            expect(agents.key?('008')).to eq(true)
            expect(agents.key?('007')).to eq(false)
            instances = manager.get_instances_for_deployment('mycloud')
            expect(instances[0].id).to eq('007')
            expect(instances[0].agent_id).to eq('008')

            expect(event_processor).to_not receive(:process)
            manager.analyze_agents
          end
        end
      end

      describe '#get_agents_for_deployment' do
        it 'can provide agent information for a deployment' do
          instance1 = { 'id' => 'iuuid1', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator' }
          instance2 = { 'id' => 'iuuid2', 'agent_id' => '008', 'index' => '0', 'job' => 'nats' }
          instance3 = { 'id' => 'iuuid3', 'agent_id' => '009', 'index' => '28', 'job' => 'mysql_node' }

          manager.sync_deployments([{ 'name' => 'mycloud' }])
          manager.sync_deployment_state({ 'name' => 'mycloud' }, [instance1, instance2, instance3])

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
          instance1 = { 'id' => 'iuuid1',  'index' => '0', 'job' => 'mutator', 'expects_vm' => true }
          instance2 = { 'id' => 'iuuid2',  'index' => '0', 'job' => 'nats', 'expects_vm' => true }
          instance3 = { 'id' => 'iuuid3',  'index' => '28', 'job' => 'mysql_node', 'expects_vm' => true }

          manager.sync_deployments([{ 'name' => 'mycloud' }])
          manager.sync_deployment_state({ 'name' => 'mycloud' }, [instance1, instance2, instance3])

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
          manager.sync_deployments([{ 'name' => 'mycloud' }])
          manager.sync_deployment_state({ 'name' => 'mycloud' }, [{ 'id' => 'iuuid', 'job' => 'zb', 'index' => '0',
                                                                    'expects_vm' => true }])

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
        let(:instance1) do
          {
            'id' => 'instance-uuid-1', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator',
            'vm_created_at' => '2018-08-07T22:47:39'
          }
        end
        let(:instance2) do
          {
            'id' => 'instance-uuid-2', 'agent_id' => '008', 'index' => '1', 'job' => 'mutator',
            'vm_created_at' => '2018-08-07T22:47:39'
          }
        end
        let(:instance3) do
          {
            'id' => 'instance-uuid-3', 'agent_id' => '009', 'index' => '2', 'job' => 'mutator2',
            'vm_created_at' => '2018-08-07T22:47:39'
          }
        end

        before do
          manager.sync_deployments([{ 'name' => 'mycloud' }])
        end

        it 'can analyze agent' do
          manager.sync_deployment_state({ 'name' => 'mycloud' }, [instance1])

          expect(manager.analyze_agents).to eq(1)
        end

        context('when multiple agents time out in different deployments') do
          let(:instance4) do
            {
              'id' => 'instance-uuid-4', 'agent_id' => '010', 'index' => '3', 'job' => 'mutator2',
              'vm_created_at' => '2018-08-07T22:47:39'
            }
          end
          before do
            manager.sync_deployments([{ 'name' => 'mycloud' }, { 'name' => 'mycloud-2' }])
            manager.sync_deployment_state({ 'name' => 'mycloud' }, [instance1, instance2, instance3])
            manager.sync_deployment_state({ 'name' => 'mycloud-2' }, [instance4])
            ts = Time.now
            allow(Time).to receive(:now).and_return(ts + Bhm.intervals.agent_timeout + 10)
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

        it 'alerts on a timed out agent' do
          manager.sync_deployment_state({ 'name' => 'mycloud' }, [instance1])
          ts = Time.now
          allow(Time).to receive(:now).and_return(ts + Bhm.intervals.agent_timeout + 10)

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

          expect(event_processor).to receive(:process).with(
            :alert,
            severity: 2,
            category: 'deployment_health',
            source: 'mycloud',
            title: 'mycloud has instances with timed out agents',
            created_at: anything,
            deployment: 'mycloud',
            jobs_to_instance_ids: { 'mutator' => ['instance-uuid-1'] },
          )

          manager.analyze_agents
        end

        it 'does not alert on a new VM' do
          instancenew = {
            'id' => 'instance-uuid-1', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator',
            'vm_created_at' => Time.now.utc.iso8601.to_s
          }
          manager.sync_deployment_state({ 'name' => 'mycloud' }, [instancenew])
          ts = Time.now
          allow(Time).to receive(:now).and_return(ts + Bhm.intervals.agent_timeout + 10)

          expect(event_processor).not_to receive(:process)

          manager.analyze_agents
        end

        it 'does not alert on timed-out recent rogue agent' do
          # agents are in @rogue_agents if an instance couldn't be found when event received
          alert654 = JSON.dump('id' => '654', 'severity' => 2, 'title' => 'zb', 'summary' => 'zbb',
                               'created_at' => Time.now.utc.to_i)
          manager.sync_deployment_state({ 'name' => 'mycloud' }, [])
          manager.process_event(:heartbeat, 'hm.agent.alert.654', alert654)
          ts = Time.now
          allow(Time).to receive(:now).and_return(ts + Bhm.intervals.agent_timeout + 1)

          expect(event_processor).not_to receive(:process)

          manager.analyze_agents
          expect(manager.agents_count).to eq(1)
        end

        it 'does not alert on timed-out stale rogue agent' do
          # agent.rogue is true if rogue_agent_alert has elapsed and agent.deployment is nil
          alert654 = JSON.dump('id' => '654', 'severity' => 2, 'title' => 'zb', 'summary' => 'zbb',
                               'created_at' => Time.now.utc.to_i)
          manager.sync_deployment_state({ 'name' => 'mycloud' }, [])
          manager.process_event(:heartbeat, 'hm.agent.alert.654', alert654)
          ts = Time.now
          allow(Time).to receive(:now).and_return(ts + Bhm.intervals.rogue_agent_alert + 1)

          expect(event_processor).not_to receive(:process)

          manager.analyze_agents
          expect(manager.agents_count).to eq(0)
        end

        it 'can analyze all agents' do
          expect(manager.analyze_agents).to eq(0)

          manager.sync_deployment_state({ 'name' => 'mycloud' }, [instance1, instance2, instance3])
          expect(manager.analyze_agents).to eq(3)

          alert = JSON.dump('id' => '778', 'severity' => 2, 'title' => 'zb', 'summary' => 'zbb',
                            'created_at' => Time.now.utc.to_i)

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
          allow(Time).to receive(:now).and_return(ts + [Bhm.intervals.agent_timeout, Bhm.intervals.rogue_agent_alert].max + 10)

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
        instance = {
          'id' => 'instance-uuid', 'agent_id' => '007', 'index' => '0', 'cid' => 'cuuid', 'job' => 'mutator',
          'expects_vm' => true
        }

        expect(manager.alert_needed?(Bhm::Instance.create(instance))).to be(false)
      end

      context 'when the instances expects a VM, and does not have one' do
        it 'sends an alert' do
          instance = {
            'id' => 'instance-uuid', 'agent_id' => '007', 'index' => '0', 'cid' => nil, 'job' => 'mutator',
            'expects_vm' => true
          }

          expect(manager.alert_needed?(Bhm::Instance.create(instance))).to be(true)
        end
      end
    end

    describe '#analyze_instances' do
      let(:instance1) do
        {
          'id' => 'instance-uuid-1', 'agent_id' => '007', 'index' => '0', 'job' => 'mutator', 'expects_vm' => true,
          'vm_created_at' => '2018-08-07T22:47:39'
        }
      end
      let(:instance2) do
        {
          'id' => 'instance-uuid-2', 'agent_id' => '008', 'index' => '1', 'job' => 'mutator', 'expects_vm' => true,
          'vm_created_at' => '2018-08-07T22:47:39'
        }
      end

      before do
        manager.sync_deployments([{ 'name' => 'my_deployment' }])
      end

      it 'analyzes nothing for empty instances' do
        expect(event_processor).to_not receive(:process)
        expect(manager.analyze_instances).to eq(0)
      end

      context 'instances with vms' do
        before do
          instance1['cid'] = 'cuuid'
          instance2['cid'] = 'cuuid'
        end

        it 'can analyze all instances' do
          manager.sync_deployment_state({ 'name' => 'my_deployment' }, [instance1, instance2])
          expect(event_processor).to_not receive(:process)

          expect(manager.analyze_instances).to eq(2)
        end
      end

      it 'alerts on an instance without VM' do
        manager.sync_deployment_state({ 'name' => 'my_deployment' }, [instance1])
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

        expect(event_processor).to receive(:process).with(
          :alert,
          severity: 2,
          category: 'deployment_health',
          source: 'my_deployment',
          title: 'my_deployment has instances which do not have VMs',
          created_at: anything,
          deployment: 'my_deployment',
          jobs_to_instance_ids: { 'mutator' => ['instance-uuid-1'] },
        )

        expect(manager.analyze_instances).to eq(1)
      end

      context('when instances have no vm in different deployments') do
        let(:instance3) do
          {
            'id' => 'instance-uuid-3', 'agent_id' => '009', 'index' => '2', 'job' => 'mutator2', 'expects_vm' => true,
            'vm_created_at' => '2018-08-07T22:47:39'
          }
        end
        let(:instance4) do
          {
            'id' => 'instance-uuid-4', 'agent_id' => '010', 'index' => '3', 'job' => 'mutator2', 'expects_vm' => true,
            'vm_created_at' => '2018-08-07T22:47:39'
          }
        end
        before do
          manager.sync_deployments([{ 'name' => 'mycloud' }, { 'name' => 'mycloud-2' }])
          manager.sync_deployment_state({ 'name' => 'mycloud' }, [instance1, instance2, instance3])
          manager.sync_deployment_state({ 'name' => 'mycloud-2' }, [instance4])
        end

        it 'sends an alert for each instance with missing vm' do
          expect(event_processor).to receive(:process).with(
            :alert,
            hash_including(category: 'vm_health'),
          ).exactly(4).times

          manager.analyze_instances
        end

        it 'sends an aggregated alert per deployment' do
          expect(event_processor).to receive(:process)
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
        Bhm.config = Psych.load_file(sample_config)
        allow(mock_nats).to receive(:subscribe)
        allow(Bhm).to receive(:nats).and_return(mock_nats)
        allow(EM).to receive(:schedule).and_yield
      end

      it 'has the tsdb plugin' do
        expect(Bhm::Plugins::Tsdb).to receive(:new).with(
          'host' => 'localhost',
          'port' => 4242,
        ).and_call_original

        manager.setup_events
      end
    end

    context 'when loading plugin not found' do
      before do
        config = Psych.load_file(sample_config)
        config['plugins'] << { 'name' => 'joes_plugin_thing', 'events' => %w[alerts heartbeats] }
        Bhm.config = config
      end

      it 'raises an error' do
        expect do
          manager.setup_events
        end.to raise_error(Bhm::PluginError, "Cannot find 'joes_plugin_thing' plugin")
      end
    end
  end
end
