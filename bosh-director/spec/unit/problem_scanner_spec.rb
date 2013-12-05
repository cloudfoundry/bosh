require 'spec_helper'

module Bosh::Director
  describe ProblemScanner do
    let!(:deployment) { Models::Deployment.make(:name => 'mycloud') }
    let!(:problem_scanner) { ProblemScanner.new(deployment) }

    describe 'reset' do
      it 'should mark all open problems as closed' do
        problem = Models::DeploymentProblem.make(counter: 1,
                                                 type: 'inactive_disk',
                                                 deployment: deployment,
                                                 state: 'open')

        problem_scanner.reset

        Models::DeploymentProblem.any?(&:open?).should be(false)
        Models::DeploymentProblem[problem.id].state.should == 'closed'
      end

      context 'when reseting a specific list of job instances' do
        it 'only marks the specific job instances that are open as closed' do
          instance1 = Models::Instance.make(deployment: deployment, job: 'job1', index: 0)
          instance2 = Models::Instance.make(deployment: deployment, job: 'job1', index: 1)

          problem1 = Models::DeploymentProblem.make(counter: 1,
                                                    type: 'inactive_disk',
                                                    deployment: deployment,
                                                    state: 'open',
                                                    resource_id: instance1.vm.id)
          problem2 = Models::DeploymentProblem.make(counter: 1,
                                                    type: 'inactive_disk',
                                                    deployment: deployment,
                                                    state: 'open',
                                                    resource_id: instance2.vm.id)
          problem_scanner.reset([['job1', 0]])
          Models::DeploymentProblem[problem1.id].state.should == 'closed'
          Models::DeploymentProblem[problem2.id].state.should == 'open'
        end
      end
    end

    describe 'disc scan' do
      it 'identifies inactive disks' do
        2.times do |i|
          vm = Models::Vm.make(cid: 'vm-cid', agent_id: "agent-#{i}", deployment: deployment)
          instance = Models::Instance.make(vm: vm, deployment: deployment, job: "job-#{i}", index: 0)
          Models::PersistentDisk.make(instance_id: instance.id, active: false)
        end

        Models::DeploymentProblem.count.should == 0
        problem_scanner.reset
        problem_scanner.scan_disks
        Models::DeploymentProblem.count.should == 2

        Models::DeploymentProblem.all.each do |problem|
          problem.counter.should == 1
          problem.type.should == 'inactive_disk'
          problem.deployment.should == deployment
          problem.state.should == 'open'
        end

        problem_scanner.scan_disks

        Models::DeploymentProblem.all.each do |problem|
          problem.counter.should == 2
          problem.last_seen_at.should >= problem.created_at
          problem.type.should == 'inactive_disk'
          problem.deployment.should == deployment
          problem.state.should == 'open'
        end
      end
    end

    describe 'Mount info scan' do
      it 'should not consider unresponsive agents for the disk info mismatch' do
        vm = Models::Vm.make(cid: 'vm-cid', agent_id: 'agent-1', deployment: deployment)
        instance = Models::Instance.make(vm: vm, deployment: deployment, job: 'job-1', index: 0)
        unresponsive_agent = double('Bosh::Director::AgentClient')

        Config.stub(:cloud).and_return(instance_double('Bosh::Cloud', has_vm?: true))

        Models::PersistentDisk.make(instance_id: instance.id, active: true)

        AgentClient.stub(:with_defaults).with('agent-1', anything).and_return(unresponsive_agent)
        unresponsive_agent.should_receive(:get_state).and_raise(RpcTimeout)

        # for unresponsive agents pick up VM id from the DB
        problem_scanner.reset
        problem_scanner.scan_vms

        Models::DeploymentProblem.count.should == 1
        problem = Models::DeploymentProblem.first
        problem.state.should == 'open'
        problem.type.should == 'unresponsive_agent'
        problem.deployment.should == deployment
        problem.resource_id.should == 1
        problem.data.should == {}
      end

      it 'old agents without list_disk method' do
        vm = Models::Vm.make(cid: 'vm-cid', agent_id: 'agent', deployment: deployment)
        instance = Models::Instance.make(vm: vm, deployment: deployment, job: 'job', index: 1)
        Models::PersistentDisk.make(instance_id: instance.id, active: true)

        agent = double('agent')
        AgentClient.stub(:with_defaults).with('agent', anything).and_return(agent)

        good_state = {
          'deployment' => 'mycloud',
          'job' => {'name' => 'job'},
          'index' => 1
        }

        agent.should_receive(:get_state).and_return(good_state)
        agent.should_receive(:list_disk).and_raise("No 'list_disk' method")

        # if list_disk is not present fall back to db --> no error
        problem_scanner.reset
        problem_scanner.scan_vms
        problem_scanner.scan_disks
        Models::DeploymentProblem.count.should == 0
      end

      it 'scan not-mounted active disk' do
        vm = Models::Vm.make(cid: 'vm-cid', agent_id: 'agent', deployment: deployment)
        instance = Models::Instance.make(vm: vm, deployment: deployment, job: 'job', index: 1)
        Models::PersistentDisk.make(instance_id: instance.id, active: true)

        agent = double('agent')
        AgentClient.stub(:with_defaults).with('agent', anything).and_return(agent)

        good_state = {
          'deployment' => 'mycloud',
          'job' => {'name' => 'job'},
          'index' => 1
        }
        agent.should_receive(:get_state).and_return(good_state)
        agent.should_receive(:list_disk).and_raise(RpcTimeout)

        # if list_disk is not present fall back to db --> no error
        problem_scanner.reset
        problem_scanner.scan_vms
        problem_scanner.scan_disks
        Models::DeploymentProblem.count.should == 1
        problem = Models::DeploymentProblem.first
        problem.state.should == 'open'
        problem.type.should == 'mount_info_mismatch'
        problem.deployment.should == deployment
        problem.resource_id.should == 1
        problem.data.should == {'owner_vms' => []}
      end

      it 'scan disk when agent reports it has no disks attached' do
        vm = Models::Vm.make(cid: 'vm-cid', agent_id: 'agent', deployment: deployment)
        instance = Models::Instance.make(vm: vm, deployment: deployment, job: 'job', index: 1)
        Models::PersistentDisk.make(instance_id: instance.id, active: true)

        agent = double('agent')
        AgentClient.stub(:with_defaults).with('agent', anything).and_return(agent)

        good_state = {
          'deployment' => 'mycloud',
          'job' => {'name' => 'job'},
          'index' => 1
        }
        agent.should_receive(:get_state).and_return(good_state)
        agent.should_receive(:list_disk).and_return([])

        # if list_disk is not present fall back to db --> no error
        problem_scanner.reset
        problem_scanner.scan_vms
        problem_scanner.scan_disks
        Models::DeploymentProblem.count.should == 1
        problem = Models::DeploymentProblem.first
        problem.state.should == 'open'
        problem.type.should == 'mount_info_mismatch'
        problem.deployment.should == deployment
        problem.resource_id.should == 1
        problem.data.should == {'owner_vms' => []}
      end

      it 'scan disks mounted twice' do
        (1..2).each do |i|
          vm = Models::Vm.make(cid: "vm-cid-#{i}", agent_id: "agent-#{i}", deployment: deployment)
          Models::Instance.make(vm: vm, deployment: deployment, job: "job-#{i}", index: i)
        end
        Models::PersistentDisk.make(instance_id: 1, active: true, disk_cid: 'disk-cid-1')

        agent_1 = double('agent-1')
        agent_2 = double('agent-2')

        AgentClient.stub(:with_defaults).with('agent-1', anything).and_return(agent_1)
        AgentClient.stub(:with_defaults).with('agent-2', anything).and_return(agent_2)

        good_state_1 = {
          'deployment' => 'mycloud',
          'job' => {'name' => 'job-1'},
          'index' => 1
        }
        agent_1.should_receive(:get_state).and_return(good_state_1)

        good_state_2 = {
          'deployment' => 'mycloud',
          'job' => {'name' => 'job-2'},
          'index' => 2
        }
        agent_2.should_receive(:get_state).and_return(good_state_2)

        # disk-cid-1 mounted on both 'agent_1' and 'agent_2'
        agent_1.should_receive(:list_disk).and_return(['disk-cid-1'])
        agent_2.should_receive(:list_disk).and_return(['disk-cid-1'])

        problem_scanner.reset
        problem_scanner.scan_vms
        problem_scanner.scan_disks
        Models::DeploymentProblem.count.should == 1
        problem = Models::DeploymentProblem.first
        problem.state.should == 'open'
        problem.type.should == 'mount_info_mismatch'
        problem.deployment.should == deployment
        problem.resource_id.should == 1
        problem.data['owner_vms'].sort.should == ['vm-cid-1', 'vm-cid-2'].sort
      end

      it 'scan disks mounted in a different VM' do
        (1..2).each do |i|
          vm = Models::Vm.make(cid: "vm-cid-#{i}", agent_id: "agent-#{i}", deployment: deployment)
          instance = Models::Instance.make(vm: vm, deployment: deployment, job: "job-#{i}", index: i)
          Models::PersistentDisk.make(instance_id: instance.id, active: true, disk_cid: "disk-cid-#{i}")
        end

        agent_1 = double('agent-1')
        agent_2 = double('agent-2')

        AgentClient.stub(:with_defaults).with('agent-1', anything).
          and_return(agent_1)
        AgentClient.stub(:with_defaults).with('agent-2', anything).
          and_return(agent_2)

        good_state_1 = {
          'deployment' => 'mycloud',
          'job' => {'name' => 'job-1'},
          'index' => 1
        }
        agent_1.should_receive(:get_state).and_return(good_state_1)

        good_state_2 = {
          'deployment' => 'mycloud',
          'job' => {'name' => 'job-2'},
          'index' => 2
        }
        agent_2.should_receive(:get_state).and_return(good_state_2)

        # mount info flipped
        agent_1.should_receive(:list_disk).and_return(['disk-cid-2'])
        agent_2.should_receive(:list_disk).and_return(['disk-cid-1'])

        problem_scanner.reset
        problem_scanner.scan_vms
        problem_scanner.scan_disks
        Models::DeploymentProblem.count.should == 2

        problem = Models::DeploymentProblem.all[0]
        problem.counter.should == 1
        problem.type.should == 'mount_info_mismatch'
        problem.deployment.should == deployment
        problem.state.should == 'open'
        problem.resource_id.should == 1
        problem.data.should == {'owner_vms' => ['vm-cid-2']}

        problem = Models::DeploymentProblem.all[1]
        problem.counter.should == 1
        problem.type.should == 'mount_info_mismatch'
        problem.deployment.should == deployment
        problem.state.should == 'open'
        problem.resource_id.should == 2
        problem.data.should == {'owner_vms' => ['vm-cid-1']}
      end
    end

    describe 'VM scan' do
      let(:cloud) { instance_double('Bosh::Cloud') }

      context 'when cloud.has_vm?' do
        before do
          3.times do |i|
            vm = Models::Vm.make(cid: 'vm-cid', agent_id: "agent-#{i}", deployment: deployment)
            Models::Instance.make(vm: vm, deployment: deployment, job: "job-#{i}", index: i)
          end
          unresponsive_agent1 = double(AgentClient)
          unresponsive_agent2 = double(AgentClient)
          responsive_agent = double(AgentClient)

          AgentClient.stub(:with_defaults).with('agent-0', anything).and_return(unresponsive_agent1)
          AgentClient.stub(:with_defaults).with('agent-1', anything).and_return(unresponsive_agent2)
          AgentClient.stub(:with_defaults).with('agent-2', anything).and_return(responsive_agent)

          # Unresponsive agent
          unresponsive_agent1.stub(:get_state).and_raise(RpcTimeout)
          unresponsive_agent2.stub(:get_state).and_raise(RpcTimeout)

          # Working agent
          good_state = {
            'deployment' => 'mycloud',
            'job' => {'name' => 'job-2'},
            'index' => 2
          }
          responsive_agent.stub(:get_state).and_return(good_state)
          responsive_agent.stub(:list_disk).and_return([])
          Config.stub(:cloud).and_return(cloud)
          cloud.stub(:has_vm?).with('vm-cid').and_return(true)
        end

        context 'is implemented' do
          it 'scans a subset of vms' do
            problem_scanner.should_receive(:track_and_log).with('Checking VM states').and_yield
            problem_scanner.should_receive(:track_and_log).with('1 OK, 1 unresponsive, 0 missing, 0 unbound, 0 out of sync')

            expect {
              problem_scanner.scan_vms([['job-1', 1], ['job-2', 2]])
            }.to change { Models::DeploymentProblem.count }.by(1)
          end

          it 'scans for unresponsive agents' do
            problem_scanner.should_receive(:track_and_log).with('Checking VM states').and_call_original
            problem_scanner.should_receive(:track_and_log).with('1 OK, 2 unresponsive, 0 missing, 0 unbound, 0 out of sync')

            problem_scanner.scan_vms
            Models::DeploymentProblem.count.should == 2

            problem = Models::DeploymentProblem.first
            problem.state.should == 'open'
            problem.type.should == 'unresponsive_agent'
            problem.deployment.should == deployment
            problem.resource_id.should == 1
            problem.data.should == {}
          end

          it 'scans for missing vms' do
            cloud.should_receive(:has_vm?).with('vm-cid').and_return(false)

            problem_scanner.should_receive(:track_and_log).with('Checking VM states').and_call_original
            problem_scanner.should_receive(:track_and_log).with('1 OK, 1 unresponsive, 1 missing, 0 unbound, 0 out of sync')

            problem_scanner.scan_vms
            Models::DeploymentProblem.count.should == 2

            problem = Models::DeploymentProblem.first
            problem.state.should == 'open'
            problem.type.should == 'missing_vm'
            problem.deployment.should == deployment
            problem.resource_id.should == 1
            problem.data.should == {}
          end
        end

        context 'is not implemented' do
          it 'falls back to only identifying unresponsive agents' do
            cloud.should_receive(:has_vm?).with('vm-cid').and_raise(Bosh::Clouds::NotImplemented)

            problem_scanner.should_receive(:track_and_log).with('Checking VM states').and_call_original
            problem_scanner.should_receive(:track_and_log).with('1 OK, 2 unresponsive, 0 missing, 0 unbound, 0 out of sync')

            problem_scanner.reset
            problem_scanner.scan_vms
            Models::DeploymentProblem.count.should == 2

            problem = Models::DeploymentProblem.first
            problem.state.should == 'open'
            problem.type.should == 'unresponsive_agent'
            problem.deployment.should == deployment
            problem.resource_id.should == 1
            problem.data.should == {}
          end
        end
      end

      it 'scans for unbound instance vms' do
        vms = (1..3).collect do |i|
          Models::Vm.make(agent_id: "agent-#{i}", deployment: deployment)
        end

        Models::Instance.make(vm: vms[1], deployment: deployment, job: 'mysql_node', index: 3)

        agent_1 = double('agent-1')
        agent_2 = double('agent-2')
        agent_3 = double('agent-3')
        AgentClient.stub(:with_defaults).with('agent-1', anything).and_return(agent_1)
        AgentClient.stub(:with_defaults).with('agent-2', anything).and_return(agent_2)
        AgentClient.stub(:with_defaults).with('agent-3', anything).and_return(agent_3)

        # valid idle resource pool VM
        agent_1.should_receive(:get_state).and_return({'deployment' => 'mycloud'})
        agent_1.should_receive(:list_disk).and_return([])

        # valid bound instance
        bound_vm_state = {
          'deployment' => 'mycloud',
          'job' => {'name' => 'mysql_node'},
          'index' => 3
        }
        agent_2.should_receive(:get_state).and_return(bound_vm_state)
        agent_2.should_receive(:list_disk).and_return([])

        # problem: unbound instance VM
        unbound_vm_state = {
          'deployment' => 'mycloud',
          'job' => {'name' => 'test-job'},
          'index' => 22
        }
        agent_3.should_receive(:get_state).and_return(unbound_vm_state)
        agent_3.should_receive(:list_disk).and_return([])
        problem_scanner.should_receive(:track_and_log).with('Checking VM states').and_call_original
        problem_scanner.should_receive(:track_and_log).with('2 OK, 0 unresponsive, 0 missing, 1 unbound, 0 out of sync')

        problem_scanner.reset
        problem_scanner.scan_vms

        Models::DeploymentProblem.count.should == 1

        problem = Models::DeploymentProblem.first
        problem.state.should == 'open'
        problem.type.should == 'unbound_instance_vm'
        problem.deployment.should == deployment
        problem.resource_id.should == 3
        problem.data.should == {'job' => 'test-job', 'index' => 22}
      end

      it 'scans for out-of-sync VMs' do
        vm = Models::Vm.make(agent_id: 'out-of-sync-agent-id', deployment: deployment)
        Models::Instance.make(vm: vm, deployment: deployment, job: 'mysql_node', index: 3)

        out_of_sync_agent = double('out_of_sync_agent-id')

        AgentClient.stub(:with_defaults).with('out-of-sync-agent-id', anything).and_return(out_of_sync_agent)

        out_of_sync_state = {
          'deployment' => 'mycloud',
          'job' => {'name' => 'mysql_node'},
          'index' => 4
        }

        out_of_sync_agent.should_receive(:get_state).and_return(out_of_sync_state)
        out_of_sync_agent.should_receive(:list_disk).and_return([])

        problem_scanner.should_receive(:track_and_log).with('Checking VM states').and_call_original
        problem_scanner.should_receive(:track_and_log).with('0 OK, 0 unresponsive, 0 missing, 0 unbound, 1 out of sync')

        problem_scanner.reset
        problem_scanner.scan_vms

        Models::DeploymentProblem.count.should == 1

        problem = Models::DeploymentProblem.first
        problem.state.should == 'open'
        problem.type.should == 'out_of_sync_vm'
        problem.deployment.should == deployment
        problem.resource_id.should == vm.id
        problem.data.should == {'job' => 'mysql_node', 'index' => 4, 'deployment' => 'mycloud'}
      end
    end
  end
end
