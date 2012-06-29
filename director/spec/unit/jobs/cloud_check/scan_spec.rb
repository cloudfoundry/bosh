# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../../spec_helper", __FILE__)

describe Bosh::Director::Jobs::CloudCheck::Scan do

  describe "perform scan" do

    before(:each) do
      @mycloud = Bosh::Director::Models::Deployment.make(:name => "mycloud")
      @job = Bosh::Director::Jobs::CloudCheck::Scan.new("mycloud")
    end

    it "performs disk scan and VM scan while holding a deployment lock" do
      lock = mock("deployment_lock")
      Bosh::Director::Lock.stub!(:new).with("lock:deployment:mycloud").and_return(lock)

      lock.should_receive(:try_lock).and_yield
      @job.should_receive(:scan_vms).ordered
      @job.should_receive(:scan_disks).ordered
      @job.perform.should == "scan complete"
    end

    describe "disc scan" do
      before(:each) do
        2.times do |i|
          instance = Bosh::Director::Models::Instance.make(:deployment => @mycloud)
          Bosh::Director::Models::PersistentDisk.make(:instance_id => instance.id, :active => false)
        end
      end

      it "identifies inactive disks" do
        Bosh::Director::Models::DeploymentProblem.count.should == 0
        @job.scan_disks
        Bosh::Director::Models::DeploymentProblem.count.should == 2

        Bosh::Director::Models::DeploymentProblem.all.each do |problem|
          problem.counter.should == 1
          problem.type.should == "inactive_disk"
          problem.deployment.should == @mycloud
          problem.state.should == "open"
        end

        @job.scan_disks

        Bosh::Director::Models::DeploymentProblem.all.each do |problem|
          problem.counter.should == 2
          problem.last_seen_at.should >= problem.created_at
          problem.type.should == "inactive_disk"
          problem.deployment.should == @mycloud
          problem.state.should == "open"
        end
      end
    end

    describe "Mount info scan" do
      it "unresponsive agents should not be considered disk info mismatch" do
        lock = mock("deployment_lock")
        Bosh::Director::Lock.stub!(:new).with("lock:deployment:mycloud").and_return(lock)
        lock.should_receive(:try_lock).and_yield

        vm = Bosh::Director::Models::Vm.make(:cid => "vm-cid", :agent_id => "agent", :deployment => @mycloud)
        instance = Bosh::Director::Models::Instance.make(:vm => vm, :deployment => @mycloud,
                                                         :job => "job", :index => 0)
        Bosh::Director::Models::PersistentDisk.make(:instance_id => instance.id, :active => true)

        agent = mock("agent")
        Bosh::Director::AgentClient.stub!(:new).with("agent", anything).and_return(agent)
        agent.should_receive(:get_state).and_raise(Bosh::Director::RpcTimeout)
        # for unresponsive agents pick up VM id from the DB
        @job.perform == "scan complete"

        Bosh::Director::Models::DeploymentProblem.count.should == 1
        problem = Bosh::Director::Models::DeploymentProblem.first
        problem.state.should == "open"
        problem.type.should == "unresponsive_agent"
        problem.deployment.should == @mycloud
        problem.resource_id.should == 1
        problem.data.should == {}
      end

      it "old agents without list_disk method" do
        lock = mock("deployment_lock")
        Bosh::Director::Lock.stub!(:new).with("lock:deployment:mycloud").and_return(lock)
        lock.should_receive(:try_lock).and_yield

        vm = Bosh::Director::Models::Vm.make(:cid => "vm-cid", :agent_id => "agent", :deployment => @mycloud)
        instance = Bosh::Director::Models::Instance.make(:vm => vm, :deployment => @mycloud,
                                                         :job => "job", :index => 1)
        disk = Bosh::Director::Models::PersistentDisk.make(:instance_id => instance.id, :active => true)

        agent = mock("agent")
        Bosh::Director::AgentClient.stub!(:new).with("agent", anything).and_return(agent)

        good_state = {
          "deployment" => "mycloud",
          "job" => { "name" => "job" },
          "index" => 1
        }
        agent.should_receive(:get_state).and_return(good_state)
        agent.should_receive(:list_disk).and_raise("No 'list_disk' method")

        # if list_disk is not present fall back to db --> no error
        @job.perform == "scan complete"
        Bosh::Director::Models::DeploymentProblem.count.should == 0
      end

      it "scan not-mounted active disk" do
        lock = mock("deployment_lock")
        Bosh::Director::Lock.stub!(:new).with("lock:deployment:mycloud").and_return(lock)
        lock.should_receive(:try_lock).and_yield

        vm = Bosh::Director::Models::Vm.make(:cid => "vm-cid", :agent_id => "agent", :deployment => @mycloud)
        instance = Bosh::Director::Models::Instance.make(:vm => vm, :deployment => @mycloud,
                                                         :job => "job", :index => 1)
        disk = Bosh::Director::Models::PersistentDisk.make(:instance_id => instance.id, :active => true)

        agent = mock("agent")
        Bosh::Director::AgentClient.stub!(:new).with("agent", anything).and_return(agent)

        good_state = {
          "deployment" => "mycloud",
          "job" => { "name" => "job" },
          "index" => 1
        }
        agent.should_receive(:get_state).and_return(good_state)
        agent.should_receive(:list_disk).and_return([])

        # if list_disk is not present fall back to db --> no error
        @job.perform == "scan complete"
        Bosh::Director::Models::DeploymentProblem.count.should == 1
        problem = Bosh::Director::Models::DeploymentProblem.first
        problem.state.should == "open"
        problem.type.should == "mount_info_mismatch"
        problem.deployment.should == @mycloud
        problem.resource_id.should == 1
        problem.data.should == {'owner_vms' => []}
      end

      it "scan disks mounted twice" do
        lock = mock("deployment_lock")
        Bosh::Director::Lock.stub!(:new).with("lock:deployment:mycloud").and_return(lock)
        lock.should_receive(:try_lock).and_yield

        (1..2).each do |i|
          vm = Bosh::Director::Models::Vm.make(:cid => "vm-cid-#{i}", :agent_id => "agent-#{i}", :deployment => @mycloud)
          instance = Bosh::Director::Models::Instance.make(:vm => vm, :deployment => @mycloud,
                                                           :job => "job-#{i}", :index => i)
        end
        Bosh::Director::Models::PersistentDisk.make(:instance_id => 1, :active => true, :disk_cid => 'disk-cid-1')

        agent_1 = mock("agent-1")
        agent_2 = mock("agent-2")

        Bosh::Director::AgentClient.stub!(:new).with("agent-1", anything).and_return(agent_1)
        Bosh::Director::AgentClient.stub!(:new).with("agent-2", anything).and_return(agent_2)

        good_state_1 = {
          "deployment" => "mycloud",
          "job" => { "name" => "job-1" },
          "index" => 1
        }
        agent_1.should_receive(:get_state).and_return(good_state_1)

        good_state_2 = {
          "deployment" => "mycloud",
          "job" => { "name" => "job-2" },
          "index" => 2
        }
        agent_2.should_receive(:get_state).and_return(good_state_2)

        # disk-cid-1 mounted on both 'agent_1' and 'agent_2'
        agent_1.should_receive(:list_disk).and_return(["disk-cid-1"])
        agent_2.should_receive(:list_disk).and_return(["disk-cid-1"])

        @job.perform
        Bosh::Director::Models::DeploymentProblem.count.should == 1
        problem = Bosh::Director::Models::DeploymentProblem.first
        problem.state.should == "open"
        problem.type.should == "mount_info_mismatch"
        problem.deployment.should == @mycloud
        problem.resource_id.should == 1
        problem.data["owner_vms"].sort.should == ["vm-cid-1", "vm-cid-2"].sort
      end

      it "scan disks mounted in a different VM" do
        lock = mock("deployment_lock")
        Bosh::Director::Lock.stub!(:new).with("lock:deployment:mycloud").and_return(lock)
        lock.should_receive(:try_lock).and_yield

        (1..2).each do |i|
          vm = Bosh::Director::Models::Vm.make(:cid => "vm-cid-#{i}", :agent_id => "agent-#{i}", :deployment => @mycloud)
          instance = Bosh::Director::Models::Instance.make(:vm => vm, :deployment => @mycloud,
                                                           :job => "job-#{i}", :index => i)
          Bosh::Director::Models::PersistentDisk.make(:instance_id => instance.id, :active => true, :disk_cid => "disk-cid-#{i}")
        end

        agent_1 = mock("agent-1")
        agent_2 = mock("agent-2")

        Bosh::Director::AgentClient.stub!(:new).with("agent-1", anything).and_return(agent_1)
        Bosh::Director::AgentClient.stub!(:new).with("agent-2", anything).and_return(agent_2)

        good_state_1 = {
          "deployment" => "mycloud",
          "job" => { "name" => "job-1" },
          "index" => 1
        }
        agent_1.should_receive(:get_state).and_return(good_state_1)

        good_state_2 = {
          "deployment" => "mycloud",
          "job" => { "name" => "job-2" },
          "index" => 2
        }
        agent_2.should_receive(:get_state).and_return(good_state_2)

        # mount info flipped
        agent_1.should_receive(:list_disk).and_return(["disk-cid-2"])
        agent_2.should_receive(:list_disk).and_return(["disk-cid-1"])

        @job.perform
        Bosh::Director::Models::DeploymentProblem.count.should == 2

        problem = Bosh::Director::Models::DeploymentProblem.all[0]
        problem.counter.should == 1
        problem.type.should == "mount_info_mismatch"
        problem.deployment.should == @mycloud
        problem.state.should == "open"
        problem.resource_id.should == 1
        problem.data.should == {'owner_vms' => ['vm-cid-2']}

        problem = Bosh::Director::Models::DeploymentProblem.all[1]
        problem.counter.should == 1
        problem.type.should == "mount_info_mismatch"
        problem.deployment.should == @mycloud
        problem.state.should == "open"
        problem.resource_id.should == 2
        problem.data.should == {'owner_vms' => ['vm-cid-1']}
      end

    end


    describe "VM scan" do
      it "scans for unresponsive agents" do
        2.times do |i|
          vm = Bosh::Director::Models::Vm.make(:cid => "vm-cid", :agent_id => "agent-#{i}", :deployment => @mycloud)
          instance = Bosh::Director::Models::Instance.make(:vm => vm, :deployment => @mycloud,
                                                           :job => "job-#{i}", :index => i)
        end

        agent_1 = mock("agent-1")
        agent_2 = mock("agent-2")

        Bosh::Director::AgentClient.stub!(:new).with("agent-0", anything).and_return(agent_1)
        Bosh::Director::AgentClient.stub!(:new).with("agent-1", anything).and_return(agent_2)

        # Unresponsive agent
        agent_1.should_receive(:get_state).and_raise(Bosh::Director::RpcTimeout)
        # Working agent
        good_state = {
          "deployment" => "mycloud",
          "job" => { "name" => "job-1" },
          "index" => 1
        }
        agent_2.should_receive(:get_state).and_return(good_state)
        agent_2.should_receive(:list_disk).and_return([])

        @job.scan_vms
        Bosh::Director::Models::DeploymentProblem.count.should == 1

        problem = Bosh::Director::Models::DeploymentProblem.first
        problem.state.should == "open"
        problem.type.should == "unresponsive_agent"
        problem.deployment.should == @mycloud
        problem.resource_id.should == 1
        problem.data.should == {}
      end

      it "scans for unbound instance vms" do
        vms = (1..3).collect do |i|
          Bosh::Director::Models::Vm.make(:agent_id => "agent-#{i}", :deployment => @mycloud)
        end

        Bosh::Director::Models::Instance.make(:vm => vms[1], :deployment => @mycloud,
                                              :job => "mysql_node", :index => 3)

        agent_1 = mock("agent-1")
        agent_2 = mock("agent-2")
        agent_3 = mock("agent-3")
        Bosh::Director::AgentClient.stub!(:new).with("agent-1", anything).and_return(agent_1)
        Bosh::Director::AgentClient.stub!(:new).with("agent-2", anything).and_return(agent_2)
        Bosh::Director::AgentClient.stub!(:new).with("agent-3", anything).and_return(agent_3)

        # valid idle resource pool VM
        agent_1.should_receive(:get_state).and_return({"deployment" => "mycloud"})
        agent_1.should_receive(:list_disk).and_return([])

        # valid bound instance
        bound_vm_state = {
          "deployment" => "mycloud",
          "job" => { "name" => "mysql_node" },
          "index" => 3
        }
        agent_2.should_receive(:get_state).and_return(bound_vm_state)
        agent_2.should_receive(:list_disk).and_return([])

        # problem: unbound instance VM
        unbound_vm_state = {
          "deployment" => "mycloud",
          "job" => { "name" => "test-job" },
          "index" => 22
        }
        agent_3.should_receive(:get_state).and_return(unbound_vm_state)
        agent_3.should_receive(:list_disk).and_return([])

        @job.scan_vms

        Bosh::Director::Models::DeploymentProblem.count.should == 1

        problem = Bosh::Director::Models::DeploymentProblem.first
        problem.state.should == "open"
        problem.type.should == "unbound_instance_vm"
        problem.deployment.should == @mycloud
        problem.resource_id.should == 3
        problem.data.should == { "job" => "test-job", "index" => 22 }
      end

      it "scans for out-of-sync VMs" do
        vm = Bosh::Director::Models::Vm.make(:agent_id => "agent-id", :deployment => @mycloud)

        Bosh::Director::Models::Instance.make(:vm => vm, :deployment => @mycloud,
                                              :job => "mysql_node", :index => 3)

        agent = mock("agent-id")
        Bosh::Director::AgentClient.stub!(:new).with("agent-id", anything).and_return(agent)

        out_of_sync_state = {
          "deployment" => "mycloud",
          "job" => { "name" => "mysql_node" },
          "index" => 4
        }

        agent.should_receive(:get_state).and_return(out_of_sync_state)
        agent.should_receive(:list_disk).and_return([])

        @job.scan_vms

        Bosh::Director::Models::DeploymentProblem.count.should == 1

        problem = Bosh::Director::Models::DeploymentProblem.first
        problem.state.should == "open"
        problem.type.should == "out_of_sync_vm"
        problem.deployment.should == @mycloud
        problem.resource_id.should == vm.id
        problem.data.should == { "job" => "mysql_node", "index" => 4, "deployment" => "mycloud" }
      end
    end
  end
end
