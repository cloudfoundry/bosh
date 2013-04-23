require "spec_helper"

describe Bosh::Director::ProblemScanner do
  let!(:deployment) { BDM::Deployment.make(:name => "mycloud") }
  let!(:problem_scanner) { Bosh::Director::ProblemScanner.new("mycloud") }

  describe "#reset" do
    it "should mark all open problems as closed" do
      problem = BDM::DeploymentProblem.make({
                                                :counter => 1,
                                                :type => 'inactive_disk',
                                                :deployment => deployment,
                                                :state => 'open'
                                            })

      problem_scanner.reset

      BDM::DeploymentProblem.any?(&:open?).should be_false
      BDM::DeploymentProblem[problem.id].state.should == "closed"
    end
  end

  describe "disc scan" do
    it "identifies inactive disks" do
      2.times do |i|
        vm = BDM::Vm.make(:cid => "vm-cid", :agent_id => "agent-#{i}", :deployment => deployment)
        instance = BDM::Instance.make(:vm => vm, :deployment => deployment, :job => "job-#{i}", :index => 0)
        BDM::PersistentDisk.make(:instance_id => instance.id, :active => false)
      end

      BDM::DeploymentProblem.count.should == 0
      problem_scanner.reset
      problem_scanner.scan_disks
      BDM::DeploymentProblem.count.should == 2

      BDM::DeploymentProblem.all.each do |problem|
        problem.counter.should == 1
        problem.type.should == "inactive_disk"
        problem.deployment.should == deployment
        problem.state.should == "open"
      end

      problem_scanner.scan_disks

      BDM::DeploymentProblem.all.each do |problem|
        problem.counter.should == 2
        problem.last_seen_at.should >= problem.created_at
        problem.type.should == "inactive_disk"
        problem.deployment.should == deployment
        problem.state.should == "open"
      end
    end
  end

  describe "Mount info scan" do
    it "should not consider unresponsive agents for the disk info mismatch" do
      vm = BDM::Vm.make(:cid => "vm-cid", :agent_id => "agent-1", :deployment => deployment)
      instance = BDM::Instance.make(:vm => vm, :deployment => deployment, :job => "job-1", :index => 0)
      unresponsive_agent = double(BD::AgentClient)

      BD::Config.stub(:cloud).and_return(double(Bosh::Cloud, has_vm?: true))

      BDM::PersistentDisk.make(:instance_id => instance.id, :active => true)

      BD::AgentClient.stub!(:new).with("agent-1", anything).and_return(unresponsive_agent)
      unresponsive_agent.should_receive(:get_state).and_raise(BD::RpcTimeout)

      # for unresponsive agents pick up VM id from the DB
      problem_scanner.reset
      problem_scanner.scan_vms

      BDM::DeploymentProblem.count.should == 1
      problem = BDM::DeploymentProblem.first
      problem.state.should == "open"
      problem.type.should == "unresponsive_agent"
      problem.deployment.should == deployment
      problem.resource_id.should == 1
      problem.data.should == {}
    end

    # TODO: WAT?
    it "old agents without list_disk method" do
      vm = BDM::Vm.make(:cid => "vm-cid", :agent_id => "agent", :deployment => deployment)
      instance = BDM::Instance.make(:vm => vm, :deployment => deployment, :job => "job", :index => 1)
      BDM::PersistentDisk.make(:instance_id => instance.id, :active => true)

      agent = mock("agent")
      BD::AgentClient.stub!(:new).with("agent", anything).and_return(agent)

      good_state = {
          "deployment" => "mycloud",
          "job" => {"name" => "job"},
          "index" => 1
      }

      agent.should_receive(:get_state).and_return(good_state)
      agent.should_receive(:list_disk).and_raise("No 'list_disk' method")

      # if list_disk is not present fall back to db --> no error
      problem_scanner.reset
      problem_scanner.scan_vms
      problem_scanner.scan_disks
      BDM::DeploymentProblem.count.should == 0
    end

    it "scan not-mounted active disk" do
      vm = BDM::Vm.make(:cid => "vm-cid", :agent_id => "agent", :deployment => deployment)
      instance = BDM::Instance.make(:vm => vm, :deployment => deployment, :job => "job", :index => 1)
      BDM::PersistentDisk.make(:instance_id => instance.id,
                               :active => true)

      agent = mock("agent")
      BD::AgentClient.stub!(:new).with("agent", anything).and_return(agent)

      good_state = {
          "deployment" => "mycloud",
          "job" => {"name" => "job"},
          "index" => 1
      }
      agent.should_receive(:get_state).and_return(good_state)
      agent.should_receive(:list_disk).and_return([])

      # if list_disk is not present fall back to db --> no error
      problem_scanner.reset
      problem_scanner.scan_vms
      problem_scanner.scan_disks
      BDM::DeploymentProblem.count.should == 1
      problem = BDM::DeploymentProblem.first
      problem.state.should == "open"
      problem.type.should == "mount_info_mismatch"
      problem.deployment.should == deployment
      problem.resource_id.should == 1
      problem.data.should == {'owner_vms' => []}
    end

    it "scan disks mounted twice" do
      (1..2).each do |i|
        vm = BDM::Vm.make(:cid => "vm-cid-#{i}", :agent_id => "agent-#{i}",
                          :deployment => deployment)
        BDM::Instance.make(:vm => vm, :deployment => deployment,
                           :job => "job-#{i}", :index => i)
      end
      BDM::PersistentDisk.make(:instance_id => 1, :active => true,
                               :disk_cid => "disk-cid-1")

      agent_1 = mock("agent-1")
      agent_2 = mock("agent-2")

      BD::AgentClient.stub!(:new).with("agent-1", anything).
          and_return(agent_1)
      BD::AgentClient.stub!(:new).with("agent-2", anything).
          and_return(agent_2)

      good_state_1 = {
          "deployment" => "mycloud",
          "job" => {"name" => "job-1"},
          "index" => 1
      }
      agent_1.should_receive(:get_state).and_return(good_state_1)

      good_state_2 = {
          "deployment" => "mycloud",
          "job" => {"name" => "job-2"},
          "index" => 2
      }
      agent_2.should_receive(:get_state).and_return(good_state_2)

      # disk-cid-1 mounted on both 'agent_1' and 'agent_2'
      agent_1.should_receive(:list_disk).and_return(["disk-cid-1"])
      agent_2.should_receive(:list_disk).and_return(["disk-cid-1"])

      problem_scanner.reset
      problem_scanner.scan_vms
      problem_scanner.scan_disks
      BDM::DeploymentProblem.count.should == 1
      problem = BDM::DeploymentProblem.first
      problem.state.should == "open"
      problem.type.should == "mount_info_mismatch"
      problem.deployment.should == deployment
      problem.resource_id.should == 1
      problem.data["owner_vms"].sort.should == ["vm-cid-1", "vm-cid-2"].sort
    end

    it "scan disks mounted in a different VM" do
      (1..2).each do |i|
        vm = BDM::Vm.make(:cid => "vm-cid-#{i}", :agent_id => "agent-#{i}",
                          :deployment => deployment)
        instance = BDM::Instance.make(:vm => vm, :deployment => deployment,
                                      :job => "job-#{i}", :index => i)
        BDM::PersistentDisk.make(:instance_id => instance.id, :active => true,
                                 :disk_cid => "disk-cid-#{i}")
      end

      agent_1 = mock("agent-1")
      agent_2 = mock("agent-2")

      BD::AgentClient.stub!(:new).with("agent-1", anything).
          and_return(agent_1)
      BD::AgentClient.stub!(:new).with("agent-2", anything).
          and_return(agent_2)

      good_state_1 = {
          "deployment" => "mycloud",
          "job" => {"name" => "job-1"},
          "index" => 1
      }
      agent_1.should_receive(:get_state).and_return(good_state_1)

      good_state_2 = {
          "deployment" => "mycloud",
          "job" => {"name" => "job-2"},
          "index" => 2
      }
      agent_2.should_receive(:get_state).and_return(good_state_2)

      # mount info flipped
      agent_1.should_receive(:list_disk).and_return(["disk-cid-2"])
      agent_2.should_receive(:list_disk).and_return(["disk-cid-1"])

      problem_scanner.reset
      problem_scanner.scan_vms
      problem_scanner.scan_disks
      BDM::DeploymentProblem.count.should == 2

      problem = BDM::DeploymentProblem.all[0]
      problem.counter.should == 1
      problem.type.should == "mount_info_mismatch"
      problem.deployment.should == deployment
      problem.state.should == "open"
      problem.resource_id.should == 1
      problem.data.should == {"owner_vms" => ["vm-cid-2"]}

      problem = BDM::DeploymentProblem.all[1]
      problem.counter.should == 1
      problem.type.should == "mount_info_mismatch"
      problem.deployment.should == deployment
      problem.state.should == "open"
      problem.resource_id.should == 2
      problem.data.should == {"owner_vms" => ["vm-cid-1"]}
    end

  end

  describe "VM scan" do
    it 'scans a subset of vms'

    it "scans for unresponsive agents" do
      2.times do |i|
        vm = BDM::Vm.make(cid: 'vm-cid', agent_id: "agent-#{i}", deployment: deployment)
        BDM::Instance.make(vm: vm, deployment: deployment, job: "job-#{i}", index: i)
      end

      unresponsive_agent = mock(BD::AgentClient)
      responsive_agent = mock(BD::AgentClient)

      BD::AgentClient.stub!(:new).with("agent-0", anything).and_return(unresponsive_agent)
      BD::AgentClient.stub!(:new).with("agent-1", anything).and_return(responsive_agent)

      # Unresponsive agent
      unresponsive_agent.stub(:get_state).and_raise(BD::RpcTimeout)

      # Working agent
      good_state = {
          "deployment" => "mycloud",
          "job" => {"name" => "job-1"},
          "index" => 1
      }
      responsive_agent.stub(:get_state).and_return(good_state)
      responsive_agent.stub(:list_disk).and_return([])

      fake_cloud = double(Bosh::Cloud)
      BD::Config.stub(:cloud).and_return(fake_cloud)
      fake_cloud.stub(:has_vm?).with("vm-cid").and_return(true)

      problem_scanner.should_receive(:track_and_log).with("Checking VM states").and_call_original
      problem_scanner.should_receive(:track_and_log).with("1 OK, 1 unresponsive, 0 missing, 0 unbound, 0 out of sync")

      problem_scanner.scan_vms
      BDM::DeploymentProblem.count.should == 1

      problem = BDM::DeploymentProblem.first
      problem.state.should == "open"
      problem.type.should == "unresponsive_agent"
      problem.deployment.should == deployment
      problem.resource_id.should == 1
      problem.data.should == {}
    end

    context "when cloud.has_vm? is implemented" do
      it "scans for missing vm" do
        2.times do |i|
          vm = BDM::Vm.make(cid: 'vm-cid', agent_id: "agent-#{i}", deployment: deployment)
          BDM::Instance.make(vm: vm, deployment: deployment, job: "job-#{i}", index: i)
        end

        unresponsive_agent = mock(BD::AgentClient)
        responsive_agent = mock(BD::AgentClient)

        BD::AgentClient.stub!(:new).with("agent-0", anything).and_return(unresponsive_agent)
        BD::AgentClient.stub!(:new).with("agent-1", anything).and_return(responsive_agent)

        # Unresponsive agent
        unresponsive_agent.should_receive(:get_state).and_raise(BD::RpcTimeout)

        # Working agent
        good_state = {
            "deployment" => "mycloud",
            "job" => {"name" => "job-1"},
            "index" => 1
        }

        responsive_agent.should_receive(:get_state).and_return(good_state)
        responsive_agent.should_receive(:list_disk).and_return([])
        0
        fake_cloud = double(Bosh::Cloud)
        BD::Config.stub(:cloud).and_return(fake_cloud)
        fake_cloud.should_receive(:has_vm?).with("vm-cid").and_return(false)

        problem_scanner.should_receive(:track_and_log).with("Checking VM states").and_call_original
        problem_scanner.should_receive(:track_and_log).with("1 OK, 0 unresponsive, 1 missing, 0 unbound, 0 out of sync")

        problem_scanner.scan_vms
        BDM::DeploymentProblem.count.should == 1

        problem = BDM::DeploymentProblem.first
        problem.state.should == "open"
        problem.type.should == "missing_vm"
        problem.deployment.should == deployment
        problem.resource_id.should == 1
        problem.data.should == {}
      end
    end

    context "when cloud.has_vm? is not implemented" do
      it "falls back to only identifying unresponsive agents" do
        2.times do |i|
          vm = BDM::Vm.make(cid: 'vm-cid', agent_id: "agent-#{i}", deployment: deployment)
          BDM::Instance.make(vm: vm, deployment: deployment, job: "job-#{i}", index: i)
        end

        unresponsive_agent = mock(BD::AgentClient)
        responsive_agent = mock(BD::AgentClient)

        BD::AgentClient.stub!(:new).with("agent-0", anything).and_return(unresponsive_agent)
        BD::AgentClient.stub!(:new).with("agent-1", anything).and_return(responsive_agent)

        # Unresponsive agent
        unresponsive_agent.should_receive(:get_state).and_raise(BD::RpcTimeout)

        # Working agent
        good_state = {
            "deployment" => "mycloud",
            "job" => {"name" => "job-1"},
            "index" => 1
        }

        responsive_agent.should_receive(:get_state).and_return(good_state)
        responsive_agent.should_receive(:list_disk).and_return([])
        0
        fake_cloud = double(Bosh::Cloud)
        BD::Config.stub(:cloud).and_return(fake_cloud)

        fake_cloud.should_receive(:has_vm?).with("vm-cid").and_raise(Bosh::Clouds::NotImplemented)
        problem_scanner.should_receive(:track_and_log).with("Checking VM states").and_call_original
        problem_scanner.should_receive(:track_and_log).with("1 OK, 1 unresponsive, 0 missing, 0 unbound, 0 out of sync")

        problem_scanner.reset
        problem_scanner.scan_vms
        BDM::DeploymentProblem.count.should == 1

        problem = BDM::DeploymentProblem.first
        problem.state.should == "open"
        problem.type.should == "unresponsive_agent"
        problem.deployment.should == deployment
        problem.resource_id.should == 1
        problem.data.should == {}
      end
    end

    it "scans for unbound instance vms" do
      vms = (1..3).collect do |i|
        BDM::Vm.make(:agent_id => "agent-#{i}", :deployment => deployment)
      end

      BDM::Instance.make(:vm => vms[1], :deployment => deployment,
                         :job => "mysql_node", :index => 3)

      agent_1 = mock("agent-1")
      agent_2 = mock("agent-2")
      agent_3 = mock("agent-3")
      BD::AgentClient.stub!(:new).with("agent-1", anything).
          and_return(agent_1)
      BD::AgentClient.stub!(:new).with("agent-2", anything).
          and_return(agent_2)
      BD::AgentClient.stub!(:new).with("agent-3", anything).
          and_return(agent_3)

      # valid idle resource pool VM
      agent_1.should_receive(:get_state).
          and_return({"deployment" => "mycloud"})
      agent_1.should_receive(:list_disk).and_return([])

      # valid bound instance
      bound_vm_state = {
          "deployment" => "mycloud",
          "job" => {"name" => "mysql_node"},
          "index" => 3
      }
      agent_2.should_receive(:get_state).and_return(bound_vm_state)
      agent_2.should_receive(:list_disk).and_return([])

      # problem: unbound instance VM
      unbound_vm_state = {
          "deployment" => "mycloud",
          "job" => {"name" => "test-job"},
          "index" => 22
      }
      agent_3.should_receive(:get_state).and_return(unbound_vm_state)
      agent_3.should_receive(:list_disk).and_return([])
      problem_scanner.should_receive(:track_and_log).with("Checking VM states").and_call_original
      problem_scanner.should_receive(:track_and_log).with("2 OK, 0 unresponsive, 0 missing, 1 unbound, 0 out of sync")

      problem_scanner.reset
      problem_scanner.scan_vms

      BDM::DeploymentProblem.count.should == 1

      problem = BDM::DeploymentProblem.first
      problem.state.should == "open"
      problem.type.should == "unbound_instance_vm"
      problem.deployment.should == deployment
      problem.resource_id.should == 3
      problem.data.should == {"job" => "test-job", "index" => 22}
    end

    it "scans for out-of-sync VMs" do
      vm = BDM::Vm.make(agent_id: "out-of-sync-agent-id", deployment: deployment)
      BDM::Instance.make(vm: vm, deployment: deployment, job: "mysql_node", index: 3)

      out_of_sync_agent = mock("out_of_sync_agent-id")

      BD::AgentClient.stub!(:new).with("out-of-sync-agent-id", anything).and_return(out_of_sync_agent)

      out_of_sync_state = {
          "deployment" => "mycloud",
          "job" => {"name" => "mysql_node"},
          "index" => 4
      }

      out_of_sync_agent.should_receive(:get_state).and_return(out_of_sync_state)
      out_of_sync_agent.should_receive(:list_disk).and_return([])

      problem_scanner.should_receive(:track_and_log).with("Checking VM states").and_call_original
      problem_scanner.should_receive(:track_and_log).with("0 OK, 0 unresponsive, 0 missing, 0 unbound, 1 out of sync")

      problem_scanner.reset
      problem_scanner.scan_vms

      BDM::DeploymentProblem.count.should == 1

      problem = BDM::DeploymentProblem.first
      problem.state.should == "open"
      problem.type.should == "out_of_sync_vm"
      problem.deployment.should == deployment
      problem.resource_id.should == vm.id
      problem.data.should == {"job" => "mysql_node", "index" => 4, "deployment" => "mycloud"}

    end
  end
end
