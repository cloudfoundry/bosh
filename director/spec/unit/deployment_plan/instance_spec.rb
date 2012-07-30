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
  describe "updating deployment" do
    it "needs to smartly compare specs before deciding to update a job" do
      @deployment = make_deployment("mycloud")
      BD::DeploymentPlan::Job.any_instance.stub(:initialize)
      @plan = mock(BD::DeploymentPlan, :model => @deployment)
      @job = BD::DeploymentPlan::Job.new(@plan)

      @job.release = mock(BD::DeploymentPlan::Release)
      @job.release.should_receive(:name).twice.and_return("hbase-release")

      mock_template = mock(BD::DeploymentPlan::Template)
      mock_template.should_receive(:name).exactly(4).times.and_return(
        "hbase_slave")
      mock_template.should_receive(:version).exactly(4).times.and_return("2")
      mock_template.should_receive(:sha1).exactly(4).times.and_return(
        "24aeaf29768a100d500615dc02ae6126e019f99f")
      mock_template.should_receive(:blobstore_id).exactly(4).times.and_return(
        "4ec237cb-5f07-4658-aabe-787c82f39c76")
      mock_template.should_receive(:logs).exactly(4).times

      @job.templates = [mock_template]
      @job.should_receive(:instance_state).and_return("some_state")
      instance = make(@job, 0)
      @job.stub!(:name).and_return("dea")
      instance.current_state = {
        "job" => {
          "name" => "hbase_slave",
          "release" => "hbase-release",
          "template" => "hbase_slave",
          "version" => "0.9-dev",
          "sha1" => "a8ab636b7c340f98891178096a44c09487194f03",
          "blobstore_id" => "e2e4e58e-a40e-43ec-bac5-fc50457d5563"
        }
      }
      instance.job_changed?.should == false
      # Check that the old way of comparing would say that the job has changed.
      (@job.spec == instance.current_state).should == false
    end
  end
end
