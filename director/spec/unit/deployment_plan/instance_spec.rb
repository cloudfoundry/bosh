# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::DeploymentPlan::Instance do

  def make(job, index)
    BD::DeploymentPlan::Instance.new(job, index)
  end

  def make_deployment(name)
    BD::Models::Deployment.make(:name => name)
  end

  it "trusts current state to have current IP for dynamic network" do
    plan = mock(BD::DeploymentPlan)

    network = BD::DeploymentPlan::DynamicNetwork.new(plan, {
      "name" => "net_a",
      "cloud_properties" => {"foo" => "bar"}
    })

    plan.stub!(:network).with("net_a").and_return(network)

    job = mock(BD::DeploymentPlan::Job, :deployment => plan)

    job.stub(:instance_state).with(0).and_return("started")
    job.stub(:default_network).and_return({})

    reservation = BD::NetworkReservation.new_dynamic
    network.reserve(reservation)

    instance = make(job, 0)
    instance.add_network_reservation("net_a", reservation)

    instance.network_settings.should == {
      "net_a" => {
        "type" => "dynamic",
        "cloud_properties" => {"foo" => "bar"}
      }
    }

    net_a = {
      "type" => "dynamic",
      "ip" => "10.0.0.6",
      "netmask" => "255.255.255.0",
      "gateway" => "10.0.0.1",
      "cloud_properties" => {"bar" => "baz"}
    }

    instance.current_state = {
      "networks" => {"net_a" => net_a},
    }

    instance.network_settings.should == {"net_a" => net_a}
  end

  describe "binding unallocated VM" do
    before(:each) do
      @deployment = make_deployment("mycloud")
      @plan = mock(BD::DeploymentPlan, :model => @deployment)
      @job = mock(BD::DeploymentPlan::Job, :deployment => @plan)
      @job.stub!(:name).and_return("dea")
      @job.stub!(:instance_state).with(2).and_return("started")
      @instance = make(@job, 2)
    end

    it "binds a VM from job resource pool (real VM exists)" do
      net = mock(BD::DeploymentPlan::Network, :name => "net_a")
      rp = mock(BD::DeploymentPlan::ResourcePool, :network => net)
      @job.stub!(:resource_pool).and_return(rp)

      old_ip = NetAddr::CIDR.create("10.0.0.5").to_i
      idle_vm_ip = NetAddr::CIDR.create("10.0.0.3").to_i

      old_reservation = BD::NetworkReservation.new_dynamic(old_ip)
      idle_vm_reservation = BD::NetworkReservation.new_dynamic(idle_vm_ip)

      idle_vm = BD::DeploymentPlan::IdleVm.new(rp)
      idle_vm.use_reservation(idle_vm_reservation)
      idle_vm.vm = BD::Models::Vm.make

      rp.should_receive(:allocate_vm).and_return(idle_vm)

      @instance.add_network_reservation("net_a", old_reservation)
      @instance.bind_unallocated_vm

      @instance.model.should_not be_nil
      @instance.idle_vm.should == idle_vm
      idle_vm.bound_instance.should be_nil
      idle_vm.network_reservation.ip.should == idle_vm_ip
    end

    it "binds a VM from job resource pool (real VM doesn't exist)" do
      net = mock(BD::DeploymentPlan::Network, :name => "net_a")
      rp = mock(BD::DeploymentPlan::ResourcePool, :network => net)
      @job.stub!(:resource_pool).and_return(rp)

      old_ip = NetAddr::CIDR.create("10.0.0.5").to_i
      idle_vm_ip = NetAddr::CIDR.create("10.0.0.3").to_i

      old_reservation = BD::NetworkReservation.new_dynamic(old_ip)
      idle_vm_reservation = BD::NetworkReservation.new_dynamic(idle_vm_ip)

      idle_vm = BD::DeploymentPlan::IdleVm.new(rp)
      idle_vm.use_reservation(idle_vm_reservation)
      idle_vm.vm.should be_nil

      rp.should_receive(:allocate_vm).and_return(idle_vm)
      net.should_receive(:release).with(idle_vm_reservation)

      @instance.add_network_reservation("net_a", old_reservation)
      @instance.bind_unallocated_vm

      @instance.model.should_not be_nil
      @instance.idle_vm.should == idle_vm
      idle_vm.bound_instance.should == @instance
      idle_vm.network_reservation.should be_nil
    end
  end

  describe "syncing state" do
    before(:each) do
      @deployment = make_deployment("mycloud")
      @plan = mock(BD::DeploymentPlan, :model => @deployment)
      @job = mock(BD::DeploymentPlan::Job, :deployment => @plan)
      @job.stub!(:name).and_return("dea")
    end

    it "deployment plan -> DB" do
      @job.stub!(:instance_state).with(3).and_return("stopped")
      instance = make(@job, 3)

      expect {
        instance.sync_state_with_db
      }.to raise_error(BD::DirectorError, /model is not bound/)

      instance.bind_model
      instance.model.state.should == "started"
      instance.sync_state_with_db
      instance.state.should == "stopped"
      instance.model.state.should == "stopped"
    end

    it "DB -> deployment plan" do
      @job.stub!(:instance_state).with(3).and_return(nil)
      instance = make(@job, 3)

      instance.bind_model
      instance.model.update(:state => "stopped")

      instance.sync_state_with_db
      instance.model.state.should == "stopped"
      instance.state.should == "stopped"
    end

    it "needs to find state in order to sync it" do
      @job.stub!(:instance_state).with(3).and_return(nil)
      instance = make(@job, 3)

      instance.bind_model
      instance.model.should_receive(:state).and_return(nil)

      expect {
        instance.sync_state_with_db
      }.to raise_error(BD::InstanceTargetStateUndefined)
    end
  end
end
