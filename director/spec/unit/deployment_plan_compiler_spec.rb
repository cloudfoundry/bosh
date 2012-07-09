# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::DeploymentPlanCompiler do

  before(:each) do
    @cloud = stub("CPI")
    BD::Config.stub(:cloud).and_return(@cloud)
  end

  let(:plan) do
    mock(BD::DeploymentPlan)
  end

  let(:compiler) do
    BD::DeploymentPlanCompiler.new(plan)
  end

  it "should bind deployment" do
    plan.should_receive(:bind_model)
    compiler.bind_deployment
  end

  it "should bind releases" do
    r1 = stub(BD::DeploymentPlan::Release)
    r2 = stub(BD::DeploymentPlan::Release)

    plan.should_receive(:releases).and_return([r1, r2])

    r1.should_receive(:bind_model)
    r2.should_receive(:bind_model)

    compiler.bind_releases
  end

  it "should bind existing VMs" do
    vm1 = BD::Models::Vm.make
    vm2 = BD::Models::Vm.make

    plan.stub(:vms).and_return([vm1, vm2])

    compiler.should_receive(:bind_existing_vm).with(vm1, an_instance_of(Mutex))
    compiler.should_receive(:bind_existing_vm).with(vm2, an_instance_of(Mutex))

    compiler.bind_existing_deployment
  end

  it "should bind resource pools" do
    rp1 = mock(BD::DeploymentPlan::ResourcePool)
    rp2 = mock(BD::DeploymentPlan::ResourcePool)

    plan.should_receive(:resource_pools).and_return([rp1, rp2])

    rp1.should_receive(:process_idle_vms)
    rp2.should_receive(:process_idle_vms)

    compiler.bind_resource_pools
  end

  it "should bind stemcells" do
    sc1 = mock(BD::DeploymentPlan::Stemcell)
    sc2 = mock(BD::DeploymentPlan::Stemcell)

    rp1 = mock(BD::DeploymentPlan::ResourcePool, :stemcell => sc1)
    rp2 = mock(BD::DeploymentPlan::ResourcePool, :stemcell => sc2)

    plan.should_receive(:resource_pools).and_return([rp1, rp2])

    sc1.should_receive(:bind_model)
    sc2.should_receive(:bind_model)

    compiler.bind_stemcells
  end

  it "should bind templates" do
    r1 = mock(BD::DeploymentPlan::Release)
    r2 = mock(BD::DeploymentPlan::Release)

    plan.should_receive(:releases).and_return([r1, r2])

    r1.should_receive(:bind_templates)
    r2.should_receive(:bind_templates)

    compiler.bind_templates
  end

  it "should bind unallocated VMs" do
    instances = (1..4).map { |i| mock(BD::DeploymentPlan::Instance) }

    j1 = mock(BD::DeploymentPlan::Job, :instances => instances[0..1])
    j2 = mock(BD::DeploymentPlan::Job, :instances => instances[2..3])

    plan.should_receive(:jobs).and_return([j1, j2])

    instances.each do |instance|
      instance.should_receive(:bind_unallocated_vm).ordered
      instance.should_receive(:sync_state_with_db).ordered
    end

    compiler.bind_unallocated_vms
  end

end

describe Bosh::Director::DeploymentPlanCompiler do

  before(:each) do
    @cloud = stub(:Cloud)
    BD::Config.stub(:cloud).and_return(@cloud)
    @deployment_plan = stub(:DeploymentPlan)
    @deployment_plan_compiler = BD::DeploymentPlanCompiler.new(@deployment_plan)
  end

  describe :bind_existing_vm do
    before(:each) do
      @lock = Mutex.new
      @vm = BD::Models::Vm.make(:agent_id => "foo")
    end

    it "should bind an instance" do
      instance = BD::Models::Instance.make(:vm => @vm)
      state = {"state" => "foo"}
      reservations = {"foo" => "reservation"}

      @deployment_plan_compiler.should_receive(:get_state).with(@vm).
          and_return(state)
      @deployment_plan_compiler.should_receive(:get_network_reservations).
          with(state).and_return(reservations)
      @deployment_plan_compiler.should_receive(:bind_instance).
          with(instance, state, reservations)
      @deployment_plan_compiler.bind_existing_vm(@vm, @lock)
    end

    it "should bind an idle vm" do
      state = {"resource_pool" => {"name" => "baz"}}
      reservations = {"foo" => "reservation"}
      resource_pool = stub(:ResourcePool)

      @deployment_plan.stub(:resource_pool).with("baz").
          and_return(resource_pool)

      @deployment_plan_compiler.should_receive(:get_state).with(@vm).
          and_return(state)
      @deployment_plan_compiler.should_receive(:get_network_reservations).
          with(state).and_return(reservations)
      @deployment_plan_compiler.should_receive(:bind_idle_vm).
          with(@vm, resource_pool, state, reservations)
      @deployment_plan_compiler.bind_existing_vm(@vm, @lock)
    end

    it "should delete no longer needed vms" do
      state = {"resource_pool" => {"name" => "baz"}}
      reservations = {"foo" => "reservation"}

      @deployment_plan.stub(:resource_pool).with("baz").
          and_return(nil)

      @deployment_plan_compiler.should_receive(:get_state).with(@vm).
          and_return(state)
      @deployment_plan_compiler.should_receive(:get_network_reservations).
          with(state).and_return(reservations)
      @deployment_plan.should_receive(:delete_vm).with(@vm)
      @deployment_plan_compiler.bind_existing_vm(@vm, @lock)
    end
  end

  describe :bind_idle_vm do
    before(:each) do
      @network = stub(BD::DeploymentPlan::Network)
      @network.stub(:name).and_return("foo")
      @reservation = stub(:NetworkReservation)
      @resource_pool = stub(:ResourcePool)
      @resource_pool.stub(:name).and_return("baz")
      @resource_pool.stub(:network).and_return(@network)
      @idle_vm = stub(:IdleVm)
      @vm = BD::Models::Vm.make
    end

    it "should add the existing idle VM" do
      @resource_pool.should_receive(:add_idle_vm).and_return(@idle_vm)
      @idle_vm.should_receive(:vm=).with(@vm)
      @idle_vm.should_receive(:current_state=).with({"state" => "foo"})

      @deployment_plan_compiler.bind_idle_vm(
          @vm, @resource_pool, {"state" => "foo"}, {})
    end

    it "should release a static network reservation" do
      @reservation.stub(:static?).and_return(true)

      @resource_pool.should_receive(:add_idle_vm).and_return(@idle_vm)
      @idle_vm.should_receive(:vm=).with(@vm)
      @idle_vm.should_receive(:current_state=).with({"state" => "foo"})
      @network.should_receive(:release).with(@reservation)

      @deployment_plan_compiler.bind_idle_vm(
          @vm, @resource_pool, {"state" => "foo"}, {"foo" => @reservation})
    end

    it "should reuse a valid network reservation" do
      @reservation.stub(:static?).and_return(false)

      @resource_pool.should_receive(:add_idle_vm).and_return(@idle_vm)
      @idle_vm.should_receive(:vm=).with(@vm)
      @idle_vm.should_receive(:current_state=).with({"state" => "foo"})
      @idle_vm.should_receive(:use_reservation).with(@reservation)

      @deployment_plan_compiler.bind_idle_vm(
          @vm, @resource_pool, {"state" => "foo"}, {"foo" => @reservation})
    end
  end

  describe :bind_instance do
    before(:each) do
      @model = BD::Models::Instance.make(:job => "foo", :index => 3)
    end

    it "should associate the instance to the instance spec" do
      state = {"state" => "baz"}
      reservations = {"net" => "reservation"}

      instance = stub(BD::DeploymentPlan::Instance)
      resource_pool = stub(:ResourcePool)
      job = stub(BD::DeploymentPlan::Job)
      job.stub(:instance).with(3).and_return(instance)
      job.stub(:resource_pool).and_return(resource_pool)
      @deployment_plan.stub(:job).with("foo").and_return(job)
      @deployment_plan.stub(:job_rename).and_return({})
      @deployment_plan.stub(:rename_in_progress?).and_return(false)

      instance.should_receive(:use_model).with(@model)
      instance.should_receive(:current_state=).with(state)
      instance.should_receive(:take_network_reservations).with(reservations)
      resource_pool.should_receive(:mark_active_vm)

      @deployment_plan_compiler.bind_instance(@model, state, reservations)
    end

    it "should update the instance name if it is being renamed" do
      state = {"state" => "baz"}
      reservations = {"net" => "reservation"}

      instance = stub(BD::DeploymentPlan::Instance)
      resource_pool = stub(:ResourcePool)
      job = stub(BD::DeploymentPlan::Job)
      job.stub(:instance).with(3).and_return(instance)
      job.stub(:resource_pool).and_return(resource_pool)
      @deployment_plan.stub(:job).with("bar").and_return(job)
      @deployment_plan.stub(:job_rename).
        and_return({"old_name" => "foo", "new_name" => "bar"})
      @deployment_plan.stub(:rename_in_progress?).and_return(true)

      instance.should_receive(:use_model).with(@model)
      instance.should_receive(:current_state=).with(state)
      instance.should_receive(:take_network_reservations).with(reservations)
      resource_pool.should_receive(:mark_active_vm)

      @deployment_plan_compiler.bind_instance(@model, state, reservations)
    end

    it "should mark the instance for deletion when it's no longer valid" do
      state = {"state" => "baz"}
      reservations = {"net" => "reservation"}
      @deployment_plan.stub(:job).with("foo").and_return(nil)
      @deployment_plan.should_receive(:delete_instance).with(@model)
      @deployment_plan.stub(:job_rename).and_return({})
      @deployment_plan.stub(:rename_in_progress?).and_return(false)

      @deployment_plan_compiler.bind_instance(@model, state, reservations)
    end
  end

  describe :get_network_reservations do
    it "should reserve all of the networks listed in the state" do
      foo_network = stub(BD::DeploymentPlan::Network)
      bar_network = stub(BD::DeploymentPlan::Network)

      @deployment_plan.stub(:network).with("foo").and_return(foo_network)
      @deployment_plan.stub(:network).with("bar").and_return(bar_network)

      foo_reservation = nil
      foo_network.should_receive(:reserve).and_return do |reservation|
        reservation.ip.should == NetAddr::CIDR.create("1.2.3.4").to_i
        reservation.reserved = true
        foo_reservation = reservation
        true
      end

      bar_network.should_receive(:reserve).and_return do |reservation|
        reservation.ip.should == NetAddr::CIDR.create("10.20.30.40").to_i
        reservation.reserved = false
        false
      end

      @deployment_plan_compiler.get_network_reservations({
        "networks" => {
            "foo" => {
                "ip" => "1.2.3.4"
            },
            "bar" => {
                "ip" => "10.20.30.40"
            }
        }
      }).should == {"foo" => foo_reservation}
    end
  end

  describe :get_state do
    it "should return the processed agent state" do
      state = {"state" => "baz"}

      vm = BD::Models::Vm.make(:agent_id => "agent-1")
      client = stub(:AgentClient)
      BD::AgentClient.stub(:new).with("agent-1").and_return(client)

      client.should_receive(:get_state).and_return(state)
      @deployment_plan_compiler.should_receive(:verify_state).with(vm, state)
      @deployment_plan_compiler.should_receive(:migrate_legacy_state).
          with(vm, state)

      @deployment_plan_compiler.get_state(vm)
    end
  end

  describe :verify_state do
    before(:each) do
      @deployment = BD::Models::Deployment.make(:name => "foo")
      @vm = BD::Models::Vm.make(:deployment => @deployment , :cid => "foo")
      @deployment_plan.stub(:name).and_return("foo")
      @deployment_plan.stub(:model).and_return(@deployment)
    end

    it "should do nothing when VM is ok" do
      @deployment_plan_compiler.verify_state(@vm, {"deployment" => "foo"})
    end

    it "should do nothing when instance is ok" do
      BD::Models::Instance.make(
          :deployment => @deployment, :vm => @vm, :job => "bar", :index => 11)
      @deployment_plan_compiler.verify_state(@vm, {
          "deployment" => "foo",
          "job" => {
            "name" => "bar"
          },
          "index" => 11
      })
    end

    it "should make sure VM and instance belong to the same deployment" do
      other_deployment = BD::Models::Deployment.make
      BD::Models::Instance.make(
          :deployment => other_deployment, :vm => @vm, :job => "bar",
          :index => 11)
      lambda {
        @deployment_plan_compiler.verify_state(@vm, {
            "deployment" => "foo",
            "job" => {"name" => "bar"},
            "index" => 11
        })
      }.should raise_error(BD::VmInstanceOutOfSync,
                           "VM `foo' and instance `bar/11' " +
                           "don't belong to the same deployment")
    end

    it "should make sure the state is a Hash" do
      lambda {
        @deployment_plan_compiler.verify_state(@vm, "state")
      }.should raise_error(BD::AgentInvalidStateFormat, /expected Hash/)
    end

    it "should make sure the deployment name is correct" do
      lambda {
        @deployment_plan_compiler.verify_state(@vm, {"deployment" => "foz"})
      }.should raise_error(BD::AgentWrongDeployment,
                           "VM `foo' is out of sync: expected to be a part " +
                           "of deployment `foo' but is actually a part " +
                           "of deployment `foz'")
    end

    it "should make sure the job and index exist" do
      lambda {
        @deployment_plan_compiler.verify_state(@vm, {
            "deployment" => "foo",
            "job" => {"name" => "bar"},
            "index" => 11
        })
      }.should raise_error(BD::AgentUnexpectedJob,
                           "VM `foo' is out of sync: it reports itself as " +
                           "`bar/11' but there is no instance reference in DB")
    end

    it "should make sure the job and index are correct" do
      lambda {
        @deployment_plan.stub(:job_rename).and_return({})
        @deployment_plan.stub(:rename_in_progress?).and_return(false)
        BD::Models::Instance.make(
            :deployment => @deployment, :vm => @vm, :job => "bar", :index => 11)
        @deployment_plan_compiler.verify_state(@vm, {
            "deployment" => "foo",
            "job" => {"name" => "bar"},
            "index" => 22
        })
      }.should raise_error(BD::AgentJobMismatch,
                           "VM `foo' is out of sync: it reports itself as " +
                           "`bar/22' but according to DB it is `bar/11'")
    end
  end

  describe :migrate_legacy_state
  describe :bind_resource_pools

  describe :bind_instance_networks do
    before(:each) do
      @job_spec = stub(BD::DeploymentPlan::Job)
      @instance_spec = stub(BD::DeploymentPlan::Instance)
      @network_spec = stub(BD::DeploymentPlan::Network)

      @deployment_plan.stub(:jobs).and_return([@job_spec])
      @deployment_plan.stub(:network).with("network-a").
          and_return(@network_spec)

      @job_spec.stub(:name).and_return("job-a")
      @job_spec.stub(:instances).and_return([@instance_spec])

      @network_reservation = BD::NetworkReservation.new(
          :type => BD::NetworkReservation::DYNAMIC)
      @network_reservation.reserved = false

      @instance_spec.stub(:network_reservations).
          and_return({"network-a" => @network_reservation})
      @instance_spec.stub(:index).and_return(3)
    end

    it "should do nothing if the ip is already reserved" do
      @network_reservation.reserved = true
      @deployment_plan_compiler.bind_instance_networks
    end

    it "should make a network reservation" do
      @network_spec.should_receive(:reserve!).
        with(@network_reservation, "`job-a/3'")

      @deployment_plan_compiler.bind_instance_networks
    end
  end

  describe :bind_configuration do
    before(:each) do
      @template_spec = stub(:TemplateSpec)
      @job_spec = stub(BD::DeploymentPlan::Job)
      @deployment_plan.stub(:jobs).and_return([@job_spec])
    end

    it "should bind the configuration hash" do
      configuration_hasher = stub(:ConfigurationHasher)
      configuration_hasher.should_receive(:hash)
      BD::ConfigurationHasher.stub(:new).with(@job_spec).
          and_return(configuration_hasher)
      @deployment_plan_compiler.bind_configuration
    end
  end

  describe :bind_dns do
    it "should create the domain if it doesn't exist" do
      domain = nil
      @deployment_plan.should_receive(:dns_domain=).
          and_return { |*args| domain = args.first }
      @deployment_plan_compiler.bind_dns

      BD::Models::Dns::Domain.count.should == 1
      BD::Models::Dns::Domain.first.should == domain
      domain.name.should == "bosh"
      domain.type.should == "NATIVE"
    end

    it "should reuse the domain if it exists" do
      domain = BD::Models::Dns::Domain.make(:name => "bosh", :type => "NATIVE")
      @deployment_plan.should_receive(:dns_domain=).with(domain)
      @deployment_plan_compiler.bind_dns

      BD::Models::Dns::Domain.count.should == 1
    end

    it "should create the SOA record if it doesn't exist" do
      domain = BD::Models::Dns::Domain.make(:name => "bosh", :type => "NATIVE")
      @deployment_plan.should_receive(:dns_domain=)
      @deployment_plan_compiler.bind_dns

      BD::Models::Dns::Record.count.should == 1
      record = BD::Models::Dns::Record.first
      record.domain.should == domain
      record.name.should == "bosh"
      record.type.should == "SOA"
    end

    it "should reuse the SOA record if it exists" do
      domain = BD::Models::Dns::Domain.make(:name => "bosh", :type => "NATIVE")
      record = BD::Models::Dns::Record.make(:domain => domain, :name => "bosh",
                                            :type => "SOA")
      @deployment_plan.should_receive(:dns_domain=)
      @deployment_plan_compiler.bind_dns

      record.refresh

      BD::Models::Dns::Record.count.should == 1
      BD::Models::Dns::Record.first.should == record
    end
  end

  describe :bind_instance_vms
  describe :bind_instance_vm

  describe :delete_unneeded_vms do
    it "should delete unneeded VMs" do
      vm = BD::Models::Vm.make(:cid => "vm-cid")
      @deployment_plan.stub!(:unneeded_vms).and_return([vm])

      @cloud.should_receive(:delete_vm).with("vm-cid")
      @deployment_plan_compiler.delete_unneeded_vms

      BD::Models::Vm[vm.id].should be_nil
      check_event_log do |events|
        events.size.should == 2
        events.map { |e| e["stage"] }.uniq.should == ["Deleting unneeded VMs"]
        events.map { |e| e["total"] }.uniq.should == [1]
        events.map { |e| e["task"] }.uniq.should == %w(vm-cid)
      end
    end
  end

  describe :delete_unneeded_instances do
    it "should delete unneeded instances" do
      instance = BD::Models::Instance.make
      @deployment_plan.stub!(:unneeded_instances).and_return([instance])
      instance_deleter = mock("instance_deleter")
      BD::InstanceDeleter.stub!(:new).and_return(instance_deleter)

      instance_deleter.should_receive(:delete_instances).with([instance])
      @deployment_plan_compiler.delete_unneeded_instances
    end
  end
end
