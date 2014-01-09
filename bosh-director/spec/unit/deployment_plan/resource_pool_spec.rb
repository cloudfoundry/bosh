# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::DeploymentPlan::ResourcePool do

  def make(plan, spec)
    BD::DeploymentPlan::ResourcePool.new(plan, spec)
  end

  let(:valid_spec) do
    {
      "name" => "small",
      "size" => 22,
      "network" => "test",
      "stemcell" => {
        "name" => "stemcell-name",
        "version" => "0.5.2"
      },
      "cloud_properties" => {"foo" => "bar"},
      "env" => {"key" => "value"},
    }
  end

  describe "creating" do
    it "parses name, size, stemcell spec, cloud properties, env" do
      network = instance_double('Bosh::Director::DeploymentPlan::Network')

      plan = instance_double('Bosh::Director::DeploymentPlan::Planner')
      plan.stub(:network).with("test").and_return(network)

      rp = make(plan, valid_spec)
      rp.name.should == "small"
      rp.size.should == 22
      rp.stemcell.should be_kind_of(BD::DeploymentPlan::Stemcell)
      rp.stemcell.name.should == "stemcell-name"
      rp.stemcell.version.should == "0.5.2"
      rp.network.should == network
      rp.cloud_properties.should == {"foo" => "bar"}
      rp.env.should == {"key" => "value"}
    end

    it "requires name, size, cloud properties" do
      %w(name size cloud_properties).each do |key|
        spec = valid_spec.dup
        spec.delete(key)
        plan = instance_double('Bosh::Director::DeploymentPlan::Planner')

        expect {
          make(plan, spec)
        }.to raise_error(BD::ValidationMissingField)
      end
    end

    it "requires referencing an existing network" do
      spec = valid_spec.merge("network" => "foobar")
      plan = instance_double('Bosh::Director::DeploymentPlan::Planner')
      plan.stub(:network).with("foobar").and_return(nil)

      expect {
        make(plan, spec)
      }.to raise_error(BD::ResourcePoolUnknownNetwork)
    end

    it "has default env" do
      spec = valid_spec.dup
      spec.delete("env")
      network = instance_double('Bosh::Director::DeploymentPlan::Network')
      plan = instance_double('Bosh::Director::DeploymentPlan::Planner')
      plan.stub(:network).with("test").and_return(network)

      rp = make(plan, spec)
      rp.env.should == {}
    end
  end

  it "returns resource pool spec as Hash" do
    network = instance_double('Bosh::Director::DeploymentPlan::Network')
    plan = instance_double('Bosh::Director::DeploymentPlan::Planner')
    plan.stub(:network).with("test").and_return(network)

    rp = make(plan, valid_spec)
    rp.spec.should == {
      "name" => "small",
      "cloud_properties" => {"foo" => "bar"},
      "stemcell" => {"name" => "stemcell-name", "version" => "0.5.2"}
    }
  end

  it "reserves capacity up to size" do
    network = instance_double('Bosh::Director::DeploymentPlan::Network')
    plan = instance_double('Bosh::Director::DeploymentPlan::Planner')
    plan.stub(:network).with("test").and_return(network)

    rp = make(plan, valid_spec)
    rp.reserve_capacity(1)
    rp.reserve_capacity(21)

    expect {
      rp.reserve_capacity(1)
    }.to raise_error(BD::ResourcePoolNotEnoughCapacity)
  end

  describe "processing idle VMs" do
    it "creates idle vm objects for missing idle VMs" do
      network = instance_double('Bosh::Director::DeploymentPlan::Network')
      network.stub(:reserve!)

      plan = instance_double('Bosh::Director::DeploymentPlan::Planner')
      plan.stub(:network).with("test").and_return(network)

      rp = make(plan, valid_spec)
      rp.add_idle_vm
      rp.mark_active_vm
      rp.missing_vm_count.should == 20

      rp.process_idle_vms
      rp.missing_vm_count.should == 0
      rp.idle_vms.size.should == 21 # 1 is active
    end

    it "reserves dynamic networks for idle VMs that don't have reservations" do
      network = instance_double('Bosh::Director::DeploymentPlan::Network')
      plan = instance_double('Bosh::Director::DeploymentPlan::Planner')
      plan.stub(:network).with("test").and_return(network)

      rp = make(plan, valid_spec.merge("size" => 3))

      idle_vm = rp.add_idle_vm
      r1 = BD::NetworkReservation.new_dynamic
      idle_vm.use_reservation(r1)

      rp.idle_vms.select { |vm| vm.has_network_reservation? }.size.should == 1
      network.should_receive(:reserve!).
        with(an_instance_of(BD::NetworkReservation), "Resource pool `small'").
        exactly(2).times

      rp.process_idle_vms
      rp.idle_vms.select { |vm| vm.has_network_reservation? }.size.should == 3
    end
  end
end
