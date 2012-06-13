# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::ResourcePoolUpdater do
  before(:each) do
    @cloud = stub(:Cloud)
    BD::Config.stub(:cloud).and_return(@cloud)

    @resource_pool = stub(:ResourcePoolSpec)
    @resource_pool.stub(:name).and_return("large")
    @resource_pool_updater = BD::ResourcePoolUpdater.new(@resource_pool)
  end

  describe :create_missing_vms do
    it "should do nothing when everything is created" do
      pool = stub(:ThreadPool)

      @resource_pool.stub(:allocated_vms).and_return([])
      @resource_pool.stub(:idle_vms).and_return([])

      @resource_pool_updater.should_not_receive(:create_missing_vm)
      @resource_pool_updater.create_missing_vms(pool)
    end

    it "should create missing VMs" do
      pool = stub(:ThreadPool)

      idle_vm = stub(:IdleVm)
      idle_vm.stub(:vm).and_return(nil)

      @resource_pool.stub(:allocated_vms).and_return([])
      @resource_pool.stub(:idle_vms).and_return([idle_vm])

      pool.should_receive(:process).and_yield

      @resource_pool_updater.should_receive(:create_missing_vm).with(idle_vm)
      @resource_pool_updater.create_missing_vms(pool)
    end
  end

  describe :create_bound_missing_vms do
    it "should call create_missing_vms with the right filter" do
      pool = stub(:ThreadPool)

      bound_vm = stub(:IdleVm)
      bound_vm.stub(:bound_instance).and_return(stub(:InstanceSpec))
      unbound_vm = stub(:IdleVm)
      unbound_vm.stub(:bound_instance).and_return(nil)

      called = false
      @resource_pool_updater.should_receive(:create_missing_vms).
          and_return do |*args|
        called = true
        # TODO when switching to rspec 2.9.0 this needs to be changed as they
        # have changed the call to not include the proc
        filter = args[1]
        filter.call(bound_vm).should == true
        filter.call(unbound_vm).should == false
      end
      @resource_pool_updater.create_bound_missing_vms(pool)
      called.should == true
    end
  end

  describe :create_missing_vm do
    before(:each) do
      @idle_vm = stub(:IdleVm)
      @network_settings = {"network" => "settings"}
      @idle_vm.stub(:network_settings).and_return(@network_settings)
      @deployment = BD::Models::Deployment.make
      @deployment_plan = stub(:DeploymentPlan)
      @deployment_plan.stub(:model).and_return(@deployment)
      @stemcell = BD::Models::Stemcell.make
      @stemcell_spec = stub(:StemcellSpec)
      @stemcell_spec.stub(:stemcell).and_return(@stemcell)
      @resource_pool.stub(:deployment).and_return(@deployment_plan)
      @resource_pool.stub(:stemcell).and_return(@stemcell_spec)
      @cloud_properties = {"size" => "medium"}
      @resource_pool.stub(:cloud_properties).and_return(@cloud_properties)
      @environment = {"password" => "foo"}
      @resource_pool.stub(:env).and_return(@environment)
      @vm = BD::Models::Vm.make(:agent_id => "agent-1", :cid => "vm-1")
      @vm_creator = stub(:VmCreator)
      @vm_creator.stub(:create).
          with(@deployment, @stemcell, @cloud_properties, @network_settings,
               nil, @environment).
          and_return(@vm)
      BD::VmCreator.stub(:new).and_return(@vm_creator)
    end

    it "should create a VM" do
      agent = stub(:AgentClient)
      agent.should_receive(:wait_until_ready)
      agent.should_receive(:get_state).and_return({"state" => "foo"})
      BD::AgentClient.stub(:new).with("agent-1").and_return(agent)

      @resource_pool_updater.should_receive(:update_state).with(agent, @vm, @idle_vm)
      @idle_vm.should_receive(:vm=).with(@vm)
      @idle_vm.should_receive(:current_state=).with({"state" => "foo"})

      @resource_pool_updater.create_missing_vm(@idle_vm)
    end

    it "should clean up the partially created VM" do
      agent = stub(:AgentClient)
      agent.should_receive(:wait_until_ready).and_raise("timeout")
      BD::AgentClient.stub(:new).with("agent-1").and_return(agent)

      @cloud.should_receive(:delete_vm).with("vm-1")

      lambda {
        @resource_pool_updater.create_missing_vm(@idle_vm)
      }.should raise_error("timeout")

      BD::Models::Vm.count.should == 0
    end
  end

  describe :update_state
  describe :delete_extra_vms
  describe :delete_outdated_idle_vms
  describe :reserve_networks

end
