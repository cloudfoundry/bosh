require 'spec_helper'

module Bosh::Director
  describe ProblemScanner::VmScanStage do
    subject(:vm_scanner) do
      described_class.new(
        instance_manager,
        problem_register,
        cloud,
        deployment,
        event_logger,
        double(:logger, info: nil, warn: nil)
      )
    end

    let(:instance_manager) { instance_double('Bosh::Director::Api::InstanceManager') }
    let(:problem_register) { instance_double('Bosh::Director::ProblemScanner::ProblemRegister') }
    before do
      allow(problem_register).to receive(:get_vm_instance_and_disk) do |vm|
        persistent_disk_cid = vm.instance.persistent_disk_cid if vm.instance
        [vm.instance, persistent_disk_cid]
      end
    end
    let(:cloud) { instance_double('Bosh::Cloud') }
    let(:deployment) { Models::Deployment.make(name: 'fake-deployment') }
    let(:event_logger) { double(:event_logger, begin_stage: nil) }
    before do
      allow(event_logger).to receive(:track_and_log) do |_, &blk|
        blk.call if blk
      end
    end

    describe '#scan' do
      it 'scans for out-of-sync VMs' do
        vm = Models::Vm.make(agent_id: 'out-of-sync-agent-id', deployment: deployment)
        Models::Instance.make(vm: vm, deployment: deployment, job: 'mysql_node', index: 3)

        out_of_sync_agent = double('out_of_sync_agent-id')

        allow(AgentClient).to receive(:with_defaults).with('out-of-sync-agent-id', anything).and_return(out_of_sync_agent)

        out_of_sync_state = {
          'deployment' => 'fake-deployment',
          'job' => {'name' => 'mysql_node'},
          'index' => 4
        }

        expect(out_of_sync_agent).to receive(:get_state).and_return(out_of_sync_state)
        expect(out_of_sync_agent).to receive(:list_disk).and_return([])

        expect(event_logger).to receive(:track_and_log).with('Checking VM states')
        expect(event_logger).to receive(:track_and_log).with('0 OK, 0 unresponsive, 0 missing, 0 unbound, 1 out of sync')

        expect(problem_register).to receive(:problem_found).with(
          :out_of_sync_vm,
          vm,
          deployment: 'fake-deployment',
          job: 'mysql_node',
          index: 4
        )

        vm_scanner.scan
      end

      it 'scans for unbound instance vms' do
        vms = (1..3).collect do |i|
          Models::Vm.make(agent_id: "agent-#{i}", deployment: deployment)
        end

        Models::Instance.make(vm: vms[1], deployment: deployment, job: 'mysql_node', index: 3)

        agent_1 = double('agent-1')
        agent_2 = double('agent-2')
        agent_3 = double('agent-3')
        allow(AgentClient).to receive(:with_defaults).with('agent-1', anything).and_return(agent_1)
        allow(AgentClient).to receive(:with_defaults).with('agent-2', anything).and_return(agent_2)
        allow(AgentClient).to receive(:with_defaults).with('agent-3', anything).and_return(agent_3)

        # valid idle resource pool VM
        expect(agent_1).to receive(:get_state).and_return({'deployment' => 'fake-deployment'})
        expect(agent_1).to receive(:list_disk).and_return([])

        # valid bound instance
        bound_vm_state = {
          'deployment' => 'fake-deployment',
          'job' => {'name' => 'mysql_node'},
          'index' => 3
        }
        expect(agent_2).to receive(:get_state).and_return(bound_vm_state)
        expect(agent_2).to receive(:list_disk).and_return([])

        # problem: unbound instance VM
        unbound_vm_state = {
          'deployment' => 'fake-deployment',
          'job' => {'name' => 'fake-job'},
          'index' => 22
        }
        expect(agent_3).to receive(:get_state).and_return(unbound_vm_state)
        expect(agent_3).to receive(:list_disk).and_return([])

        expect(event_logger).to receive(:track_and_log).with('Checking VM states')
        expect(event_logger).to receive(:track_and_log).with('2 OK, 0 unresponsive, 0 missing, 1 unbound, 0 out of sync')

        expect(problem_register).to receive(:problem_found).with(
          :unbound_instance_vm,
          vms[2],
          job: 'fake-job',
          index: 22
        )

        vm_scanner.scan
      end

      it 'scans a subset of vms' do
        instances = (1..3).collect do |i|
          vm = Models::Vm.make(agent_id: "agent-#{i}", deployment: deployment)
          Models::Instance.make(vm: vm, deployment: deployment, job: "job-#{i}", index: i)
        end

        allow(instance_manager).to receive(:find_by_name).with('fake-deployment', 'job-1', 1).and_return(instances[0])
        allow(instance_manager).to receive(:find_by_name).with('fake-deployment', 'job-2', 2).and_return(instances[1])
        allow(instance_manager).to receive(:find_by_name).with('fake-deployment', 'job-3', 3).and_return(instances[2])

        expect(event_logger).to receive(:track_and_log).with('Checking VM states')
        expect(event_logger).to receive(:track_and_log).with('1 OK, 1 unresponsive, 0 missing, 0 unbound, 0 out of sync')

        good_agent_client = double(:agent_client, list_disk: [])
        allow(AgentClient).to receive(:with_defaults).with('agent-2', anything).and_return(good_agent_client)
        good_state = {
          'deployment' => 'fake-deployment',
          'job' => {'name' => 'job-2'},
          'index' => 2
        }
        expect(good_agent_client).to receive(:get_state).and_return(good_state)

        unresponsive_agent_client = double(:agent_client)
        allow(AgentClient).to receive(:with_defaults).with('agent-1', anything).and_return(unresponsive_agent_client)
        expect(unresponsive_agent_client).to receive(:get_state).and_raise(Bosh::Director::RpcTimeout)
        allow(cloud).to receive(:has_vm?).and_raise(Bosh::Clouds::NotImplemented)

        expect(problem_register).to receive(:problem_found).with(
          :unresponsive_agent,
          instances[0].vm
        )

        expect(AgentClient).to_not receive(:with_defaults).with('agent-3', anything)

        vm_scanner.scan([['job-1', 1], ['job-2', 2]])
      end

      context 'when agent on a VM did not respond in time' do
        let!(:unresponsive_vm1) { create_vm(0) }
        let!(:unresponsive_vm2) { create_vm(1) }
        let!(:responsive_vm) { create_vm(2) }

        def create_vm(i)
          vm = Models::Vm.make(cid: "vm-cid-#{i}", agent_id: "agent-#{i}", deployment: deployment)
          Models::Instance.make(vm: vm, deployment: deployment, job: "job-#{i}", index: i)
          vm
        end

        before do
          unresponsive_agent1 = double(AgentClient)
          unresponsive_agent2 = double(AgentClient)
          responsive_agent = double(AgentClient)
          agent_options = { timeout: 10, retry_methods: { get_state: 0}}

          allow(AgentClient).to receive(:with_defaults).with('agent-0', agent_options).and_return(unresponsive_agent1)
          allow(AgentClient).to receive(:with_defaults).with('agent-1', agent_options).and_return(unresponsive_agent2)
          allow(AgentClient).to receive(:with_defaults).with('agent-2', agent_options).and_return(responsive_agent)

          # Unresponsive agent
          allow(unresponsive_agent1).to receive(:get_state).and_raise(RpcTimeout)
          allow(unresponsive_agent2).to receive(:get_state).and_raise(RpcTimeout)

          # Working agent
          good_state = {
            'deployment' => 'fake-deployment',
            'job' => {'name' => 'job-2'},
            'index' => 2
          }
          allow(responsive_agent).to receive(:get_state).and_return(good_state)
          allow(responsive_agent).to receive(:list_disk).and_return([])
        end

        context 'when cloud implements has_vm?' do
          before do
            allow(cloud).to receive(:has_vm?).and_return(true)
          end

          context 'when cloud has VM' do
            it 'registers unresponsive agent problem' do
              expect(event_logger).to receive(:track_and_log).with('Checking VM states')
              expect(event_logger).to receive(:track_and_log).with('1 OK, 2 unresponsive, 0 missing, 0 unbound, 0 out of sync')

              expect(problem_register).to receive(:problem_found).with(
                :unresponsive_agent,
                unresponsive_vm1
              )

              expect(problem_register).to receive(:problem_found).with(
                :unresponsive_agent,
                unresponsive_vm2
              )

              vm_scanner.scan
            end
          end

          context 'when cloud does not have VM' do
            before do
              allow(cloud).to receive(:has_vm?).with('vm-cid-0').and_return(false)
            end

            it 'registers missing VM problem' do
              expect(event_logger).to receive(:track_and_log).with('Checking VM states')
              expect(event_logger).to receive(:track_and_log).with('1 OK, 1 unresponsive, 1 missing, 0 unbound, 0 out of sync')

              expect(problem_register).to receive(:problem_found).with(
                :missing_vm,
                unresponsive_vm1
              )

              expect(problem_register).to receive(:problem_found).with(
                :unresponsive_agent,
                unresponsive_vm2
              )

              vm_scanner.scan
            end
          end
        end

        context 'when cloud does not implement has_vm?' do
          before do
            allow(cloud).to receive(:has_vm?).and_raise(Bosh::Clouds::NotImplemented)
          end

          it 'registers unresponsive agent problem' do
            expect(event_logger).to receive(:track_and_log).with('Checking VM states')
            expect(event_logger).to receive(:track_and_log).with('1 OK, 2 unresponsive, 0 missing, 0 unbound, 0 out of sync')

            expect(problem_register).to receive(:problem_found).with(
              :unresponsive_agent,
              unresponsive_vm1
            )

            expect(problem_register).to receive(:problem_found).with(
              :unresponsive_agent,
              unresponsive_vm2
            )

            vm_scanner.scan
          end
        end
      end
    end

    describe 'agent_disks' do
      let(:vm) { Models::Vm.make(cid: 'vm-cid', agent_id: 'agent-1', deployment: deployment) }
      let(:instance) { Models::Instance.make(vm: vm, deployment: deployment, job: 'job-1', index: 0) }
      before { allow(cloud).to receive(:has_vm?).and_return(true) }

      let(:agent) { double('Bosh::Director::AgentClient') }
      before { allow(AgentClient).to receive(:with_defaults).with('agent-1', anything).and_return(agent) }

      before do
        Models::PersistentDisk.make(instance_id: instance.id, active: true, disk_cid: 'fake-disk-cid')
      end

      before do
        good_state = {
          'deployment' => 'fake-deployment',
          'job' => {'name' => 'job-1'},
          'index' => 0
        }

        allow(agent).to receive(:get_state).and_return(good_state)
      end

      context 'when agent is not responsive' do
        before do
          allow(agent).to receive(:get_state).and_raise(RpcTimeout)
        end

        it 'returns disk cid registered on vm' do
          expect(problem_register).to receive(:problem_found).with(:unresponsive_agent, vm)
          vm_scanner.scan
          expect(vm_scanner.agent_disks['fake-disk-cid']).to eq(['vm-cid'])
        end
      end

      context 'when agent does not support list_disk' do
        before do
          allow(agent).to receive(:list_disk).and_raise(RuntimeError.new('unknown command list_disk'))
        end

        it 'returns disk cid registered on vm' do
          expect(problem_register).to_not receive(:problem_found)
          vm_scanner.scan
          expect(vm_scanner.agent_disks['fake-disk-cid']).to eq(['vm-cid'])
        end
      end

      context 'when list_disk times out' do
        before do
          allow(agent).to receive(:list_disk).and_raise(Bosh::Director::RpcTimeout)
        end

        it 'returns empty owners' do
          expect(problem_register).to_not receive(:problem_found)
          vm_scanner.scan
          expect(vm_scanner.agent_disks.size).to eq(0)
        end
      end

      context 'when list_disk returns empty list' do
        before do
          allow(agent).to receive(:list_disk).and_return([])
        end

        it 'returns empty owners' do
          expect(problem_register).to_not receive(:problem_found)
          vm_scanner.scan
          expect(vm_scanner.agent_disks.size).to eq(0)
        end
      end

      context 'when disk is mounted twice' do
        before do
          second_vm = Models::Vm.make(cid: 'vm-cid-2', agent_id: 'agent-2', deployment: deployment)
          Models::Instance.make(vm: second_vm, deployment: deployment, job: 'job-2', index: 2)

          agent_2 = double('agent-2')
          allow(AgentClient).to receive(:with_defaults).with('agent-2', anything).and_return(agent_2)

          good_state_2 = {
            'deployment' => 'fake-deployment',
            'job' => {'name' => 'job-2'},
            'index' => 2
          }
          expect(agent_2).to receive(:get_state).and_return(good_state_2)

          expect(agent).to receive(:list_disk).and_return(['fake-disk-cid'])
          expect(agent_2).to receive(:list_disk).and_return(['fake-disk-cid'])
        end

        it 'returns all owners' do
          expect(problem_register).to_not receive(:problem_found)
          vm_scanner.scan
          expect(vm_scanner.agent_disks['fake-disk-cid']).to eq(['vm-cid', 'vm-cid-2'])
        end
      end

      context 'when disk is mounted in different VM' do
        before do
          expect(agent).to receive(:list_disk).and_return(['fake-disk-cid-2'])
        end

        it 'returns the current VM' do
          expect(problem_register).to_not receive(:problem_found)
          vm_scanner.scan
          expect(vm_scanner.agent_disks['fake-disk-cid']).to be_nil
          expect(vm_scanner.agent_disks['fake-disk-cid-2']).to eq(['vm-cid'])
        end
      end
    end
  end
end
