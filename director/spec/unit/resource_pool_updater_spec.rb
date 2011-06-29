require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::ResourcePoolUpdater do

  before(:each) do
    @cloud = mock("cloud")
    Bosh::Director::Config.stub!(:cloud).and_return(@cloud)

    @deployment = Bosh::Director::Models::Deployment.make

    @deployment_plan = mock("deployment_plan")
    @deployment_plan.stub!(:deployment).and_return(@deployment)
    @deployment_plan.stub!(:name).and_return("deployment_name")

    @stemcell = Bosh::Director::Models::Stemcell.make(:cid => "stemcell-id")

    @stemcell_spec = mock("stemcell_spec")
    @stemcell_spec.stub!(:stemcell).and_return(@stemcell)

    @resource_pool_spec = mock("resource_pool_spec")
    @resource_pool_spec.stub!(:deployment).and_return(@deployment_plan)
    @resource_pool_spec.stub!(:stemcell).and_return(@stemcell_spec)
    @resource_pool_spec.stub!(:name).and_return("test")
    @resource_pool_spec.stub!(:cloud_properties).and_return({"ram" => "2gb"})
    @resource_pool_spec.stub!(:env).and_return({})
    @resource_pool_spec.stub!(:spec).and_return({"name" => "foo"})

    event_log = Bosh::Director::EventLog.new(1, nil)
    Bosh::Director::Config.stub!(:event_logger).and_return(event_log)
  end

  def update_resource_pool(resource_pool_updater)
    thread_pool = Bosh::Director::ThreadPool.new(:max_threads => 32)

    resource_pool_updater.delete_extra_vms(thread_pool)
    thread_pool.wait

    resource_pool_updater.delete_outdated_vms(thread_pool)
    thread_pool.wait

    resource_pool_updater.create_missing_vms(thread_pool)
    thread_pool.wait
    thread_pool.shutdown
  end

  it "shouldn't do anything if nothing changed" do
    vm = Bosh::Director::Models::Vm.make
    idle_vm = mock("idle_vm")

    @resource_pool_spec.stub!(:size).and_return(1)
    @resource_pool_spec.stub!(:active_vms).and_return(0)
    @resource_pool_spec.stub!(:allocated_vms).and_return([])
    @resource_pool_spec.stub!(:idle_vms).and_return([idle_vm])
    idle_vm.stub!(:vm).and_return(vm)
    idle_vm.stub!(:changed?).and_return(false)

    resource_pool_updater = Bosh::Director::ResourcePoolUpdater.new(@resource_pool_spec)
    update_resource_pool(resource_pool_updater)

    Bosh::Director::Models::Vm.all.should == [vm]
  end

  it "should create any missing vms" do
    idle_vm = mock("idle_vm")
    agent = mock("agent")

    @resource_pool_spec.stub!(:size).and_return(1)
    @resource_pool_spec.stub!(:active_vms).and_return(0)
    @resource_pool_spec.stub!(:allocated_vms).and_return([])
    @resource_pool_spec.stub!(:idle_vms).and_return([idle_vm])

    idle_vm.stub!(:network_settings).and_return({"network_a" => {"ip" => "1.2.3.4"}})
    idle_vm.stub!(:bound_instance).and_return(nil)
    idle_vm.stub!(:vm).and_return(nil)

    @cloud.should_receive(:create_vm).with("agent-1", "stemcell-id", {"ram" => "2gb"},
                                           {"network_a" => {"ip" => "1.2.3.4"}}, nil, {}).and_return("vm-1")

    Bosh::Director::AgentClient.stub!(:new).with("agent-1").and_return(agent)

    created_vm = nil
    idle_vm.should_receive(:vm=).with do |vm|
      created_vm = vm
      vm.deployment.should == @deployment
      vm.cid.should == "vm-1"
      vm.agent_id.should == "agent-1"
      true
    end

    agent.should_receive(:wait_until_ready)
    agent.should_receive(:apply).with({"resource_pool" => {"name" => "foo"}, "networks" => {"network_a" => {"ip" => "1.2.3.4"}},
                                       "deployment" => "deployment_name"}).
        and_return({"agent_task_id" => 5, "state" => "done"})
    agent.should_receive(:get_state).and_return({"state" => "testing"})
    idle_vm.should_receive(:current_state=).with({"state" => "testing"})

    resource_pool_updater = Bosh::Director::ResourcePoolUpdater.new(@resource_pool_spec)
    resource_pool_updater.stub!(:generate_agent_id).and_return("agent-1", "invalid agent")
    update_resource_pool(resource_pool_updater)
    Bosh::Director::Models::Vm.all.should == [created_vm]
  end

  it "should set the state of the bound instance" do
    instance_spec = mock("instance")
    idle_vm = mock("idle_vm")
    agent = mock("agent")

    @resource_pool_spec.stub!(:size).and_return(1)
    @resource_pool_spec.stub!(:active_vms).and_return(0)
    @resource_pool_spec.stub!(:allocated_vms).and_return([])
    @resource_pool_spec.stub!(:idle_vms).and_return([idle_vm])

    instance_spec.stub!(:spec).and_return({"foo" => "bar", "job" => "a", "index" => 5, "release" => "release_name"})

    idle_vm.stub!(:network_settings).and_return({"network_a" => {"ip" => "1.2.3.4"}})
    idle_vm.stub!(:bound_instance).and_return(instance_spec)
    idle_vm.stub!(:vm).and_return(nil)

    @cloud.should_receive(:create_vm).with("agent-1", "stemcell-id", {"ram" => "2gb"},
                                           {"network_a" => {"ip" => "1.2.3.4"}}, nil, {}).and_return("vm-1")

    Bosh::Director::AgentClient.stub!(:new).with("agent-1").and_return(agent)

    created_vm = nil
    idle_vm.should_receive(:vm=).with do |vm|
      created_vm = vm
      vm.deployment.should == @deployment
      vm.cid.should == "vm-1"
      vm.agent_id.should == "agent-1"
      true
    end

    agent.should_receive(:wait_until_ready)
    agent.should_receive(:apply).with({"resource_pool" => {"name" => "foo"},
                                       "networks" => {"network_a" => {"ip" => "1.2.3.4"}},
                                       "deployment" => "deployment_name",
                                       "job"=>"a",
                                       "index"=>5,
                                       "release"=>"release_name"}).
        and_return({"agent_task_id" => 5, "state" => "done"})
    agent.should_receive(:get_state).and_return({"state" => "testing"})
    idle_vm.should_receive(:current_state=).with({"state" => "testing"})

    resource_pool_updater = Bosh::Director::ResourcePoolUpdater.new(@resource_pool_spec)
    resource_pool_updater.stub!(:generate_agent_id).and_return("agent-1", "invalid agent")
    update_resource_pool(resource_pool_updater)
    Bosh::Director::Models::Vm.all.should == [created_vm]
  end

  it "should delete any extra vms" do
    vm = Bosh::Director::Models::Vm.make(:cid => "vm-1")
    idle_vm = mock("idle_vm")
    agent = mock("agent")

    @resource_pool_spec.stub!(:size).and_return(0)
    @resource_pool_spec.stub!(:active_vms).and_return(0)
    @resource_pool_spec.stub!(:allocated_vms).and_return([])
    @resource_pool_spec.stub!(:idle_vms).and_return([idle_vm])

    idle_vm.stub!(:vm).and_return(vm)

    @cloud.should_receive(:delete_vm).with("vm-1")

    Bosh::Director::AgentClient.stub!(:new).with("agent-1").and_return(agent)

    resource_pool_updater = Bosh::Director::ResourcePoolUpdater.new(@resource_pool_spec)
    resource_pool_updater.stub!(:generate_agent_id).and_return("agent-1", "invalid agent")
    update_resource_pool(resource_pool_updater)

    Bosh::Director::Models::Vm.all.should be_empty
  end

  it "should update existing vms if needed" do
    old_vm = Bosh::Director::Models::Vm.make(:deployment => @deployment, :cid => "vm-1")
    idle_vm = mock("idle_vm")
    agent = mock("agent")
    current_vm = old_vm

    @resource_pool_spec.stub!(:size).and_return(1)
    @resource_pool_spec.stub!(:active_vms).and_return(0)
    @resource_pool_spec.stub!(:allocated_vms).and_return([])
    @resource_pool_spec.stub!(:idle_vms).and_return([idle_vm])

    idle_vm.stub!(:network_settings).and_return({"ip" => "1.2.3.4"})
    idle_vm.should_receive(:changed?).exactly(2).times.and_return(true)
    idle_vm.stub!(:bound_instance).and_return(nil)
    idle_vm.stub!(:vm).and_return {current_vm}

    @cloud.should_receive(:delete_vm).with("vm-1")
    @cloud.should_receive(:create_vm).with("agent-1", "stemcell-id", {"ram" => "2gb"},
                                           {"ip" => "1.2.3.4"}, nil, {}).and_return("vm-2")

    Bosh::Director::AgentClient.stub!(:new).with("agent-1").and_return(agent)

    idle_vm.should_receive(:vm=).with(nil).and_return { |vm| current_vm = vm }
    idle_vm.should_receive(:current_state=).with(nil)

    agent.should_receive(:wait_until_ready)
    agent.should_receive(:apply).with({"resource_pool" => {"name" => "foo"}, "networks" => {"ip" => "1.2.3.4"},
                                       "deployment" => "deployment_name"}).
        and_return({"agent_task_id" => 5, "state" => "done"})
    agent.should_receive(:get_state).and_return({"state" => "testing"})
    idle_vm.should_receive(:vm=).with { |vm|
      vm.deployment.should == @deployment
      vm.cid.should == "vm-2"
      vm.agent_id.should == "agent-1"
      true
    }.and_return { |vm|
      current_vm = vm
    }
    idle_vm.should_receive(:current_state=).with({"state" => "testing"})

    resource_pool_updater = Bosh::Director::ResourcePoolUpdater.new(@resource_pool_spec)
    resource_pool_updater.stub!(:generate_agent_id).and_return("agent-1", "invalid agent")
    update_resource_pool(resource_pool_updater)

    current_vm.should_not == old_vm
    Bosh::Director::Models::Vm.all.should == [current_vm]
  end

end
