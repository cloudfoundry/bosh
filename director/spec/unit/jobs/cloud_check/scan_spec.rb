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

      lock.should_receive(:lock).and_yield
      @job.should_receive(:scan_disks).ordered
      @job.should_receive(:scan_vms).ordered
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

    describe "VM scan" do
      it "scans for unresponsive agents" do
        2.times do |i|
          vm = Bosh::Director::Models::Vm.make(:cid => "vm-cid", :agent_id => "agent-#{i}", :deployment => @mycloud)
          Bosh::Director::Models::Instance.make(:vm => vm, :deployment => @mycloud,
                                                :job => "job-#{i}", :index => i)
        end

        agent_1 = mock("agent-1")
        agent_2 = mock("agent-2")

        Bosh::Director::AgentClient.stub!(:new).with("agent-0", anything).and_return(agent_1)
        Bosh::Director::AgentClient.stub!(:new).with("agent-1", anything).and_return(agent_2)

        # Unresponsive agent
        agent_1.should_receive(:get_state).and_raise(Bosh::Director::Client::TimeoutException)
        # Working agent
        good_state = {
          "deployment" => "mycloud",
          "job" => { "name" => "job-1" },
          "index" => 1
        }
        agent_2.should_receive(:get_state).and_return(good_state)

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

        # valid bound instance
        bound_vm_state = {
          "deployment" => "mycloud",
          "job" => { "name" => "mysql_node" },
          "index" => 3
        }
        agent_2.should_receive(:get_state).and_return(bound_vm_state)

        # problem: unbound instance VM
        unbound_vm_state = {
          "deployment" => "mycloud",
          "job" => { "name" => "test-job" },
          "index" => 22
        }
        agent_3.should_receive(:get_state).and_return(unbound_vm_state)

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
