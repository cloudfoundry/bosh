require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Director::ResourcePoolUpdater do

  it "shouldn't do anything if nothing changed" do
    cloud = mock("cloud")
    resource_pool = mock("resource_pool")
    vm = mock("vm")
    idle_vm = mock("idle_vm")


    Bosh::Director::Config.stub!(:cloud).and_return(cloud)
    resource_pool.stub!(:unallocated_vms).and_return(0)
    resource_pool.stub!(:idle_vms).and_return([idle_vm])
    idle_vm.stub!(:vm).and_return(vm)
    idle_vm.stub!(:changed?).and_return(false)

    resource_pool_updater = Bosh::Director::ResourcePoolUpdater.new(resource_pool)
    resource_pool_updater.update
  end

  it "should create any missing vms" do
    cloud = mock("cloud")
    deployment = mock("deployment")
    stemcell = mock("stemcell")
    vm = mock("vm")
    deployment_plan = mock("deployment_plan")
    resource_pool_spec = mock("resource_pool_spec")
    stemcell_spec = mock("stemcell_spec")
    idle_vm = mock("idle_vm")
    agent = mock("agent")

    Bosh::Director::Config.stub!(:cloud).and_return(cloud)

    deployment_plan.stub!(:deployment).and_return(deployment)
    deployment_plan.stub!(:name).and_return("deployment_name")

    resource_pool_spec.stub!(:deployment).and_return(deployment_plan)
    resource_pool_spec.stub!(:unallocated_vms).and_return(0)
    resource_pool_spec.stub!(:idle_vms).and_return([idle_vm])
    resource_pool_spec.stub!(:stemcell).and_return(stemcell_spec)
    resource_pool_spec.stub!(:cloud_properties).and_return({"ram" => "2gb"})

    stemcell_spec.stub!(:stemcell).and_return(stemcell)
    stemcell.stub!(:cid).and_return("stemcell-id")

    idle_vm.stub!(:network_settings).and_return({"network_a" => {"ip" => "1.2.3.4"}})
    idle_vm.should_receive(:vm).and_return(nil, nil)

    cloud.should_receive(:create_vm).with("agent-1", "stemcell-id", {"ram"=>"2gb"},
                                          {"network_a" => {"ip" => "1.2.3.4"}}).and_return("vm-1")

    Bosh::Director::Models::Vm.stub!(:new).and_return(vm)
    vm.stub!(:agent_id).and_return("agent-1")
    vm.should_receive(:deployment=).with(deployment)
    vm.should_receive(:agent_id=).with("agent-1")
    vm.should_receive(:cid=).with("vm-1")
    vm.should_receive(:save!)

    Bosh::Director::AgentClient.stub!(:new).with("agent-1").and_return(agent)

    idle_vm.should_receive(:vm=).with(vm)
    agent.should_receive(:wait_until_ready)
    agent.should_receive(:apply).with({"deployment" => "deployment_name"}).
        and_return({"agent_task_id" => 5, "state" => "done"})
    agent.should_receive(:get_state).and_return({"state" => "testing"})
    idle_vm.should_receive(:current_state=).with({"state" => "testing"})

    resource_pool_updater = Bosh::Director::ResourcePoolUpdater.new(resource_pool_spec)
    resource_pool_updater.stub!(:generate_agent_id).and_return("agent-1", "invalid agent")
    resource_pool_updater.update
  end

  it "should delete any extra vms" do
    cloud = mock("cloud")
    deployment = mock("deployment")
    vm = mock("vm")
    deployment_plan = mock("deployment_plan")
    resource_pool_spec = mock("resource_pool_spec")
    stemcell_spec = mock("stemcell_spec")
    idle_vm = mock("idle_vm")
    agent = mock("agent")

    Bosh::Director::Config.stub!(:cloud).and_return(cloud)

    deployment_plan.stub!(:deployment).and_return(deployment)

    resource_pool_spec.stub!(:deployment).and_return(deployment_plan)
    resource_pool_spec.stub!(:unallocated_vms).and_return(-1)
    resource_pool_spec.stub!(:idle_vms).and_return([idle_vm])
    resource_pool_spec.stub!(:stemcell).and_return(stemcell_spec)
    resource_pool_spec.stub!(:cloud_properties).and_return({"ram" => "2gb"})

    vm.stub!(:cid).and_return("vm-1")

    idle_vm.should_receive(:vm).and_return(vm)

    cloud.should_receive(:delete_vm).with("vm-1")

    Bosh::Director::AgentClient.stub!(:new).with("agent-1").and_return(agent)

    resource_pool_updater = Bosh::Director::ResourcePoolUpdater.new(resource_pool_spec)
    resource_pool_updater.stub!(:generate_agent_id).and_return("agent-1", "invalid agent")
    resource_pool_updater.update
  end

  it "should update existing vms if needed" do
    cloud = mock("cloud")
    deployment = mock("deployment")
    stemcell = mock("stemcell")
    old_vm = mock("old_vm")
    new_vm = mock("new_vm")
    deployment_plan = mock("deployment_plan")
    resource_pool_spec = mock("resource_pool_spec")
    stemcell_spec = mock("stemcell_spec")
    idle_vm = mock("idle_vm")
    agent = mock("agent")
    current_vm = old_vm

    Bosh::Director::Config.stub!(:cloud).and_return(cloud)

    deployment_plan.stub!(:deployment).and_return(deployment)
    deployment_plan.stub!(:name).and_return("deployment_name")

    resource_pool_spec.stub!(:deployment).and_return(deployment_plan)
    resource_pool_spec.stub!(:unallocated_vms).and_return(0)
    resource_pool_spec.stub!(:idle_vms).and_return([idle_vm])
    resource_pool_spec.stub!(:stemcell).and_return(stemcell_spec)
    resource_pool_spec.stub!(:cloud_properties).and_return({"ram" => "2gb"})

    stemcell_spec.stub!(:stemcell).and_return(stemcell)
    stemcell.stub!(:cid).and_return("stemcell-id")

    idle_vm.stub!(:network_settings).and_return({"ip" => "1.2.3.4"})
    idle_vm.should_receive(:changed?).and_return(true)
    idle_vm.stub!(:vm).and_return {current_vm}

    old_vm.stub!(:cid).and_return("vm-1")

    cloud.should_receive(:delete_vm).with("vm-1")
    cloud.should_receive(:create_vm).with("agent-1", "stemcell-id", {"ram"=>"2gb"},
                                          {"ip"=>"1.2.3.4"}).and_return("vm-2")

    Bosh::Director::Models::Vm.stub!(:new).and_return(new_vm)
    new_vm.stub!(:agent_id).and_return("agent-1")
    new_vm.should_receive(:deployment=).with(deployment)
    new_vm.should_receive(:agent_id=).with("agent-1")
    new_vm.should_receive(:cid=).with("vm-2")
    new_vm.should_receive(:save!)

    Bosh::Director::AgentClient.stub!(:new).with("agent-1").and_return(agent)

    idle_vm.should_receive(:vm=).with(nil).and_return {|vm| current_vm = vm}
    idle_vm.should_receive(:current_state=).with(nil)

    agent.should_receive(:wait_until_ready)
    agent.should_receive(:apply).with({"deployment" => "deployment_name"}).
        and_return({"agent_task_id" => 5, "state" => "done"})
    agent.should_receive(:get_state).and_return({"state" => "testing"})
    idle_vm.should_receive(:vm=).with(new_vm).and_return {|vm| current_vm = vm}
    idle_vm.should_receive(:current_state=).with({"state" => "testing"})

    resource_pool_updater = Bosh::Director::ResourcePoolUpdater.new(resource_pool_spec)
    resource_pool_updater.stub!(:generate_agent_id).and_return("agent-1", "invalid agent")
    resource_pool_updater.update
  end


end