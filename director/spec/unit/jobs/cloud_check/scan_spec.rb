require File.expand_path("../../../../spec_helper", __FILE__)

describe Bosh::Director::Jobs::CloudCheck::Scan do

  describe "perform scan" do

    before(:each) do
      @mycloud = Bosh::Director::Models::Deployment.make(:name => "mycloud")
      @job = Bosh::Director::Jobs::CloudCheck::Scan.new("mycloud")

      @lock = mock("deployment_lock")
      Bosh::Director::Lock.stub!(:new).with("lock:deployment:mycloud").and_return(@lock)

    end

    it "scans for inactive disk problems" do
      # Couple of inactive disks
      2.times do |idx|
        Bosh::Director::Models::PersistentDisk.make(:instance_id => idx, :active => false)
      end

      Bosh::Director::Models::DeploymentProblem.count.should == 0
      @lock.should_receive(:lock).and_yield

      # we don't care about scan_agents in this test
      @job.stub!(:scan_agents)
      @job.perform
      Bosh::Director::Models::DeploymentProblem.count.should == 2

      Bosh::Director::Models::DeploymentProblem.all.each do |problem|
        problem.counter.should == 1
        problem.type.should == "inactive_disk"
        problem.deployment.should == @mycloud
        problem.state.should == "open"
      end

      @lock.should_receive(:lock).and_yield
      @job.perform

      Bosh::Director::Models::DeploymentProblem.all.each do |problem|
        problem.counter.should == 2
        problem.last_seen_at.should >= problem.created_at
        problem.type.should == "inactive_disk"
        problem.deployment.should == @mycloud
        problem.state.should == "open"
      end
    end

    it "scans for unresponsive agents" do
      @lock.should_receive(:lock).and_yield

      # don't care about disk in this test
      @job.stub!(:scan_disks)

      2.times do |idx|
        vm = Bosh::Director::Models::Vm.make(:cid => "vm-cid", :agent_id => "agent-#{idx}")
        Bosh::Director::Models::Instance.make(:vm => vm, :deployment => @mycloud)
      end

      agent_1 = mock("agent-1")
      agent_2 = mock("agent-2")
      Bosh::Director::AgentClient.stub!(:new).with("agent-0").and_return(agent_1)
      Bosh::Director::AgentClient.stub!(:new).with("agent-1").and_return(agent_2)

      # Unresponsive agent
      agent_1.should_receive(:get_state).and_raise(Bosh::Director::Client::TimeoutException)
      # Working agent
      agent_2.should_receive(:get_state).and_return({})

      @job.perform
      Bosh::Director::Models::DeploymentProblem.count.should == 1

      Bosh::Director::Models::DeploymentProblem.all.each do |problem|
        problem.counter.should == 1
        problem.last_seen_at.should >= problem.created_at
        problem.type.should == "unresponsive_agent"
        problem.deployment.should == @mycloud
        problem.state.should == "open"
        problem.resource_id.should == 1
      end

    end

    it "scans for unbounded instance vms" do
      @lock.should_receive(:lock).and_yield

      # don't care about disk in this test
      @job.stub!(:scan_disks)

      3.times do |idx|
        vm = Bosh::Director::Models::Vm.make(:cid => "vm-cid", :agent_id => "agent-#{idx}")
        Bosh::Director::Models::Instance.make(:vm => vm, :deployment => @mycloud) if idx == 1
      end

      agent_1 = mock("agent-1")
      agent_2 = mock("agent-2")
      agent_3 = mock("agent-3")
      Bosh::Director::AgentClient.stub!(:new).with("agent-0").and_return(agent_1)
      Bosh::Director::AgentClient.stub!(:new).with("agent-1").and_return(agent_2)
      Bosh::Director::AgentClient.stub!(:new).with("agent-2").and_return(agent_3)

      # valid idle resource pool VM
      agent_1.should_receive(:get_state).and_return({})
      # valid bounded instance VM
      agent_2.should_receive(:get_state).and_return({"job" => "test-job"})
      # problem. unbounded instance VM
      agent_3.should_receive(:get_state).and_return({"job" => "test-job"})

      @job.perform
      Bosh::Director::Models::DeploymentProblem.count.should == 1

      Bosh::Director::Models::DeploymentProblem.all.each do |problem|
        problem.counter.should == 1
        problem.last_seen_at.should >= problem.created_at
        problem.type.should == "unbounded_instance_vm"
        problem.deployment.should == @mycloud
        problem.state.should == "open"
        problem.resource_id.should == 3 # agent_3 is bad
      end
    end
  end

end
