# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../../spec_helper", __FILE__)

describe Bosh::Director::Jobs::CloudCheck::Scan do

  describe "perform scan" do

    before(:each) do
      @deployment = BDM::Deployment.make(:name => "mycloud")
      @job = BD::Jobs::CloudCheck::Scan.new("mycloud")
    end

    it "performs disk scan and VM scan while holding a deployment lock" do
      @job.should_receive(:with_deployment_lock).
          with(@deployment, :timeout => 0).and_yield.ordered
      @job.should_receive(:scan_vms).ordered
      @job.should_receive(:scan_disks).ordered
      @job.perform.should == "scan complete"
    end

    describe "disc scan" do
      before(:each) do
        2.times do |i|
          instance = BDM::Instance.make(:deployment => @deployment)
          BDM::PersistentDisk.make(:instance_id => instance.id,
                                   :active => false)
        end
      end

      it "identifies inactive disks" do
        BDM::DeploymentProblem.count.should == 0
        @job.scan_disks
        BDM::DeploymentProblem.count.should == 2

        BDM::DeploymentProblem.all.each do |problem|
          problem.counter.should == 1
          problem.type.should == "inactive_disk"
          problem.deployment.should == @deployment
          problem.state.should == "open"
        end

        @job.scan_disks

        BDM::DeploymentProblem.all.each do |problem|
          problem.counter.should == 2
          problem.last_seen_at.should >= problem.created_at
          problem.type.should == "inactive_disk"
          problem.deployment.should == @deployment
          problem.state.should == "open"
        end
      end
    end

    describe "Mount info scan" do
      it "unresponsive agents should not be considered disk info mismatch" do
        vm = BDM::Vm.make(:cid => "vm-cid", :agent_id => "agent",
                          :deployment => @deployment)
        instance = BDM::Instance.make(:vm => vm, :deployment => @deployment,
                                      :job => "job", :index => 0)
        BDM::PersistentDisk.make(:instance_id => instance.id, :active => true)

        agent = mock("agent")
        BD::AgentClient.stub!(:new).with("agent", anything).and_return(agent)
        agent.should_receive(:get_state).and_raise(BD::RpcTimeout)

        @job.should_receive(:with_deployment_lock).
            with(@deployment, :timeout => 0).and_yield

        # for unresponsive agents pick up VM id from the DB
        @job.perform == "scan complete"

        BDM::DeploymentProblem.count.should == 1
        problem = BDM::DeploymentProblem.first
        problem.state.should == "open"
        problem.type.should == "unresponsive_agent"
        problem.deployment.should == @deployment
        problem.resource_id.should == 1
        problem.data.should == {}
      end

      it "old agents without list_disk method" do
        vm = BDM::Vm.make(:cid => "vm-cid", :agent_id => "agent",
                          :deployment => @deployment)
        instance = BDM::Instance.make(:vm => vm, :deployment => @deployment,
                                      :job => "job", :index => 1)
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

        @job.should_receive(:with_deployment_lock).
            with(@deployment, :timeout => 0).and_yield.ordered

        # if list_disk is not present fall back to db --> no error
        @job.perform == "scan complete"
        BDM::DeploymentProblem.count.should == 0
      end

      it "scan not-mounted active disk" do
        vm = BDM::Vm.make(:cid => "vm-cid", :agent_id => "agent",
                          :deployment => @deployment)
        instance = BDM::Instance.make(:vm => vm, :deployment => @deployment,
                                      :job => "job", :index => 1)
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

        @job.should_receive(:with_deployment_lock).
            with(@deployment, :timeout => 0).and_yield.ordered

        # if list_disk is not present fall back to db --> no error
        @job.perform == "scan complete"
        BDM::DeploymentProblem.count.should == 1
        problem = BDM::DeploymentProblem.first
        problem.state.should == "open"
        problem.type.should == "mount_info_mismatch"
        problem.deployment.should == @deployment
        problem.resource_id.should == 1
        problem.data.should == {'owner_vms' => []}
      end

      it "scan disks mounted twice" do
        (1..2).each do |i|
          vm = BDM::Vm.make(:cid => "vm-cid-#{i}", :agent_id => "agent-#{i}",
                            :deployment => @deployment)
          BDM::Instance.make(:vm => vm, :deployment => @deployment,
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

        @job.should_receive(:with_deployment_lock).
            with(@deployment, :timeout => 0).and_yield.ordered

        @job.perform
        BDM::DeploymentProblem.count.should == 1
        problem = BDM::DeploymentProblem.first
        problem.state.should == "open"
        problem.type.should == "mount_info_mismatch"
        problem.deployment.should == @deployment
        problem.resource_id.should == 1
        problem.data["owner_vms"].sort.should == ["vm-cid-1", "vm-cid-2"].sort
      end

      it "scan disks mounted in a different VM" do
        (1..2).each do |i|
          vm = BDM::Vm.make(:cid => "vm-cid-#{i}", :agent_id => "agent-#{i}",
                            :deployment => @deployment)
          instance = BDM::Instance.make(:vm => vm, :deployment => @deployment,
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

        @job.should_receive(:with_deployment_lock).
            with(@deployment, :timeout => 0).and_yield.ordered

        @job.perform
        BDM::DeploymentProblem.count.should == 2

        problem = BDM::DeploymentProblem.all[0]
        problem.counter.should == 1
        problem.type.should == "mount_info_mismatch"
        problem.deployment.should == @deployment
        problem.state.should == "open"
        problem.resource_id.should == 1
        problem.data.should == {"owner_vms" => ["vm-cid-2"]}

        problem = BDM::DeploymentProblem.all[1]
        problem.counter.should == 1
        problem.type.should == "mount_info_mismatch"
        problem.deployment.should == @deployment
        problem.state.should == "open"
        problem.resource_id.should == 2
        problem.data.should == {"owner_vms" => ["vm-cid-1"]}
      end

    end


    describe "VM scan" do
      it "scans for unresponsive agents" do
        2.times do |i|
          vm = BDM::Vm.make(:cid => "vm-cid", :agent_id => "agent-#{i}",
                            :deployment => @deployment)
          BDM::Instance.make(:vm => vm, :deployment => @deployment,
                             :job => "job-#{i}", :index => i)
        end

        agent_1 = mock("agent-1")
        agent_2 = mock("agent-2")

        BD::AgentClient.stub!(:new).with("agent-0", anything).
            and_return(agent_1)
        BD::AgentClient.stub!(:new).with("agent-1", anything).
            and_return(agent_2)

        # Unresponsive agent
        agent_1.should_receive(:get_state).and_raise(BD::RpcTimeout)

        # Working agent
        good_state = {
            "deployment" => "mycloud",
            "job" => {"name" => "job-1"},
            "index" => 1
        }
        agent_2.should_receive(:get_state).and_return(good_state)
        agent_2.should_receive(:list_disk).and_return([])

        @job.scan_vms
        BDM::DeploymentProblem.count.should == 1

        problem = BDM::DeploymentProblem.first
        problem.state.should == "open"
        problem.type.should == "unresponsive_agent"
        problem.deployment.should == @deployment
        problem.resource_id.should == 1
        problem.data.should == {}
      end

      it "scans for unbound instance vms" do
        vms = (1..3).collect do |i|
          BDM::Vm.make(:agent_id => "agent-#{i}", :deployment => @deployment)
        end

        BDM::Instance.make(:vm => vms[1], :deployment => @deployment,
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

        @job.scan_vms

        BDM::DeploymentProblem.count.should == 1

        problem = BDM::DeploymentProblem.first
        problem.state.should == "open"
        problem.type.should == "unbound_instance_vm"
        problem.deployment.should == @deployment
        problem.resource_id.should == 3
        problem.data.should == {"job" => "test-job", "index" => 22}
      end

      it "scans for out-of-sync VMs" do
        vm = BDM::Vm.make(:agent_id => "agent-id", :deployment => @deployment)

        BDM::Instance.make(:vm => vm, :deployment => @deployment,
                           :job => "mysql_node", :index => 3)

        agent = mock("agent-id")
        BD::AgentClient.stub!(:new).with("agent-id", anything).and_return(agent)

        out_of_sync_state = {
            "deployment" => "mycloud",
            "job" => {"name" => "mysql_node"},
            "index" => 4
        }

        agent.should_receive(:get_state).and_return(out_of_sync_state)
        agent.should_receive(:list_disk).and_return([])

        @job.scan_vms

        BDM::DeploymentProblem.count.should == 1

        problem = BDM::DeploymentProblem.first
        problem.state.should == "open"
        problem.type.should == "out_of_sync_vm"
        problem.deployment.should == @deployment
        problem.resource_id.should == vm.id
        problem.data.should == {"job" => "mysql_node", "index" => 4,
                                "deployment" => "mycloud"}
      end
    end
  end
end
