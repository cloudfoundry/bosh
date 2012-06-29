# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

# TODO: CLEANUP, too much duplication

describe Bosh::Director::InstanceUpdater do

  BASIC_PLAN = {
    "deployment" => "test_deployment",
    "job" => {
      "name" => "test_job",
      "blobstore_id" => "job_blob"
    },
    "release"=> {
      "name" => "test_release",
      "version" => 99
    },
    "index" => 5,
    "configuration_hash" => "config_hash",
    "packages" => {
      "test_package" => {"version" => "1"}
    },
    "persistent_disk" => 1024,
    "resource_pool" => {
      "stemcell" => {
        "name" => "ubuntu",
        "network" => "network-a",
        "version" => 3
      },
      "name" => "test_resource_pool",
      "cloud_properties" => {
        "ram" => "2GB",
        "disk" => "10GB",
        "cores" => 2
      }
    },
    "networks" => {
      "network-a" => {
        "netmask" => "255.255.255.0",
        "gw" => "10.0.0.1",
        "ip" => "10.0.0.5",
        "cloud_properties" => {"name" => "network-a"},
        "dns" => ["1.2.3.4"]
      }
    },
    "properties" => {"key" => "value"}
  }
  IDLE_PLAN = {
    "deployment" => "test_deployment",
    "job" => {
        "name" => "test_job",
        "blobstore_id" => "job_blob"
    },
    "release"=> {
        "name" => "test_release",
        "version" => 99
    },
    "index" => 5,
    "resource_pool" => {
      "stemcell" => {
        "name" => "ubuntu",
        "network" => "network-a",
        "version" => 3
      },
      "name" => "test_resource_pool",
      "cloud_properties" => {
        "ram" => "2GB",
        "disk" => "10GB",
        "cores" => 2
      }
    },
    "networks" => {
      "network-a" => {
        "netmask" => "255.255.255.0",
        "gw" => "10.0.0.1",
        "ip" => "10.0.0.5",
        "cloud_properties" => {"name" => "network-a"},
        "dns" => ["1.2.3.4"]
      }
    }
  }
  BASIC_INSTANCE_STATE = BASIC_PLAN.merge({"job_state" => "running"})
  IDLE_STATE = IDLE_PLAN.merge({"job_state" => "idle"})

  def stub_object(stub, options = {})
    options.each do |key, value|
      stub.stub!(key).and_return(value)
    end
  end

  def make_updater(spec)
    Bosh::Director::InstanceUpdater.new(spec)
  end

  before(:each) do
    @deployment = Bosh::Director::Models::Deployment.make
    @vm = Bosh::Director::Models::Vm.make(:deployment => @deployment, :agent_id => "agent-1", :cid => "vm-id")
    @instance = Bosh::Director::Models::Instance.make(:deployment => @deployment, :vm => @vm, :index => "5")
    @stemcell = Bosh::Director::Models::Stemcell.make(:cid => "stemcell-id")

    @cloud = mock("cloud")
    @agent_1 = mock("agent-1")
    @instance_spec = mock("instance_spec")
    @job_spec = mock("job_spec", :name => "job_a")
    @deployment_plan = mock("deployment_plan")
    @resource_pool_spec = mock("resource_pool_spec")
    @update_spec = mock("update_spec")
    @stemcell_spec = mock("stemcell_spec")
    @release_spec = mock("release_spec")

    @instance_spec.stub!(:job).and_return(@job_spec)
    @instance_spec.stub!(:index).and_return(@instance.index)
    @instance_spec.stub!(:model).and_return(@instance)

    @job_spec.stub!(:deployment).and_return(@deployment_plan)
    @job_spec.stub!(:resource_pool).and_return(@resource_pool_spec)
    @job_spec.stub!(:update).and_return(@update_spec)
    @job_spec.stub!(:name).and_return("test_job")
    @job_spec.stub!(:package_spec).and_return(BASIC_PLAN["packages"])
    @job_spec.stub!(:persistent_disk).and_return(BASIC_PLAN["persistent_disk"])
    @job_spec.stub!(:properties).and_return(BASIC_PLAN["properties"])
    @job_spec.stub!(:spec).and_return(BASIC_PLAN["job"])
    @job_spec.stub!(:release).and_return(@release_spec)

    @update_spec.stub!(:min_update_watch_time).and_return(0.01)
    @update_spec.stub!(:max_update_watch_time).and_return(0.01)

    @release_spec.stub!(:name).and_return("test_release")
    @release_spec.stub!(:version).and_return(99)
    @release_spec.stub!(:spec).and_return({"name" => "test_release", "version" => 99})

    @deployment_plan.stub!(:resource_pool).with("small").and_return(@resource_pool_spec)
    @deployment_plan.stub!(:model).and_return(@deployment)
    @deployment_plan.stub!(:name).and_return("test_deployment")

    @resource_pool_spec.stub!(:stemcell).and_return(@stemcell_spec)
    @resource_pool_spec.stub!(:spec).and_return(BASIC_PLAN["resource_pool"])
    @resource_pool_spec.stub!(:cloud_properties).and_return(BASIC_PLAN["resource_pool"]["cloud_properties"])
    @resource_pool_spec.stub!(:env).and_return({})

    @stemcell_spec.stub!(:model).and_return(@stemcell)

    Bosh::Director::Config.stub!(:cloud).and_return(@cloud)

    @agent_1.stub!(:id).and_return("agent-1")
    Bosh::Director::AgentClient.stub!(:new).with("agent-1").and_return(@agent_1)
  end

  it "should do a basic update" do
    stub_object(@instance_spec,
                :resource_pool_changed? => false,
                :persistent_disk_changed? => false,
                :networks_changed? => false,
                :disk_currently_attached? => false,
                :dns_changed? => false,
                :changes => Set.new,
                :state => "started")

    instance_updater = Bosh::Director::InstanceUpdater.new(@instance_spec)

    @instance_spec.stub!(:spec).and_return(BASIC_PLAN)

    @agent_1.should_receive(:drain).with("update", BASIC_PLAN).and_return(0.01)
    @agent_1.should_receive(:stop)
    @agent_1.should_receive(:apply).with(BASIC_PLAN).and_return({
      "id" => "task-1",
      "state" => "done"
    })
    @agent_1.should_receive(:get_state).and_return(BASIC_INSTANCE_STATE)
    @agent_1.should_receive(:start)

    instance_updater.update
  end

  it "should raise an error if instance is still running after stop" do
    stub_object(@instance_spec,
                :resource_pool_changed? => false,
                :persistent_disk_changed? => false,
                :networks_changed? => false,
                :disk_currently_attached? => false,
                :dns_changed? => false,
                :changes => Set.new,
                :state => "stopped")

    instance_updater = Bosh::Director::InstanceUpdater.new(@instance_spec)

    @instance_spec.stub!(:spec).and_return(BASIC_PLAN)

    @agent_1.should_receive(:drain).with("shutdown").and_return(0.01)
    @agent_1.should_receive(:stop)
    @agent_1.should_receive(:apply).with(BASIC_PLAN).and_return("id" => "task-1", "state" => "done")
    @agent_1.should_receive(:get_state).and_return(BASIC_INSTANCE_STATE.merge("job_state" => "running"))

    lambda {
      instance_updater.update
    }.should raise_error(
               BD::AgentJobNotStopped,
               "`test_job/5' is still running despite the stop command")
  end

  it "should do a basic canary update" do
    stub_object(@instance_spec,
                :resource_pool_changed? => false,
                :persistent_disk_changed? => false,
                :networks_changed? => false,
                :disk_currently_attached? => false,
                :dns_changed? => false,
                :changes => Set.new,
                :state => "started")

    instance_updater = Bosh::Director::InstanceUpdater.new(@instance_spec)

    @instance_spec.stub!(:spec).and_return(BASIC_PLAN)

    @update_spec.should_not_receive(:min_update_watch_time)
    @update_spec.should_not_receive(:max_update_watch_time)
    @update_spec.should_receive(:min_canary_watch_time).and_return(0.01)
    @update_spec.should_receive(:max_canary_watch_time).and_return(0.01)

    @agent_1.should_receive(:drain).with("update", BASIC_PLAN).and_return(0.01)
    @agent_1.should_receive(:stop)
    @agent_1.should_receive(:apply).with(BASIC_PLAN).and_return({
      "id" => "task-1",
      "state" => "done"
    })
    @agent_1.should_receive(:get_state).and_return(BASIC_INSTANCE_STATE)
    @agent_1.should_receive(:start)

    instance_updater.update(:canary => true)
  end

  it "should respect watch ranges for canary update" do
    stub_object(@instance_spec,
                :resource_pool_changed? => false,
                :persistent_disk_changed? => false,
                :networks_changed? => false,
                :disk_currently_attached? => false,
                :dns_changed? => false,
                :changes => Set.new,
                :state => "started")

    instance_updater = Bosh::Director::InstanceUpdater.new(@instance_spec)

    @instance_spec.stub!(:spec).and_return(BASIC_PLAN)

    @update_spec.should_receive(:min_canary_watch_time).and_return(1000)
    @update_spec.should_receive(:max_canary_watch_time).and_return(4999)

    @agent_1.should_receive(:drain).with("update", BASIC_PLAN).ordered.and_return(30)
    instance_updater.should_receive(:sleep).with(30).ordered
    @agent_1.should_receive(:stop).ordered
    @agent_1.should_receive(:apply).with(BASIC_PLAN).ordered.and_return({ "id" => "task-1", "state" => "done" })

    @agent_1.should_receive(:start).ordered
    instance_updater.should_receive(:sleep).with(1.0).ordered
    @agent_1.should_receive(:get_state).ordered.and_return(BASIC_INSTANCE_STATE.merge("job_state" => "failing"))
    instance_updater.should_receive(:sleep).with(1.0).ordered
    @agent_1.should_receive(:get_state).ordered.and_return(BASIC_INSTANCE_STATE.merge("job_state" => "failing"))
    instance_updater.should_receive(:sleep).with(1.0).ordered
    @agent_1.should_receive(:get_state).ordered.and_return(BASIC_INSTANCE_STATE.merge("job_state" => "running"))

    instance_updater.update(:canary => true)
  end

  it "should respect watch ranges for regular update" do
    stub_object(@instance_spec,
                :resource_pool_changed? => false,
                :persistent_disk_changed? => false,
                :networks_changed? => false,
                :disk_currently_attached? => false,
                :dns_changed? => false,
                :changes => Set.new,
                :state => "stopped")

    instance_updater = Bosh::Director::InstanceUpdater.new(@instance_spec)

    @instance_spec.stub!(:spec).and_return(BASIC_PLAN)

    @update_spec.should_receive(:min_update_watch_time).and_return(25000)
    @update_spec.should_receive(:max_update_watch_time).and_return(30000)

    @agent_1.should_receive(:drain).with("shutdown").ordered.and_return(30)
    instance_updater.should_receive(:sleep).with(30).ordered
    @agent_1.should_receive(:stop).ordered
    @agent_1.should_receive(:apply).with(BASIC_PLAN).ordered.and_return({ "id" => "task-1", "state" => "done" })

    instance_updater.should_receive(:sleep).with(25.0).ordered
    @agent_1.should_receive(:get_state).ordered.and_return(BASIC_INSTANCE_STATE.merge("job_state" => "running"))
    instance_updater.should_receive(:sleep).with(1.0).ordered
    @agent_1.should_receive(:get_state).ordered.and_return(BASIC_INSTANCE_STATE.merge("job_state" => "stopped"))

    instance_updater.update
  end

  it "should do a resource pool update" do
    @agent_2 = mock("agent-2")
    @agent_2.stub!(:id).and_return("agent-2")
    Bosh::Director::AgentClient.stub!(:new).with("agent-2").and_return(@agent_2)
    Bosh::Director::VmCreator.stub(:generate_agent_id).and_return("agent-2")

    stub_object(@instance_spec,
                :resource_pool_changed? => true,
                :persistent_disk_changed? => false,
                :networks_changed? => false,
                :disk_currently_attached? => false,
                :dns_changed? => false,
                :changes => Set.new,
                :disk_size => 0,
                :network_settings => BASIC_PLAN["networks"],
                :state => "started")

    @instance_spec.should_receive(:current_state=).with(IDLE_STATE)

    instance_updater = Bosh::Director::InstanceUpdater.new(@instance_spec)
    instance_updater.stub!(:generate_agent_id).and_return("agent-2")
    instance_updater.stub!(:cloud).and_return(@cloud)

    @instance_spec.stub!(:spec).and_return(BASIC_PLAN)

    @agent_1.should_receive(:drain).with("shutdown").and_return(0.01)
    @agent_1.should_receive(:stop)
    @cloud.should_receive(:delete_vm).with("vm-id")
    @cloud.should_receive(:create_vm).with("agent-2", "stemcell-id", BASIC_PLAN["resource_pool"]["cloud_properties"],
      BASIC_PLAN["networks"], [], {}).and_return("vm-id-2")

    @agent_2.should_receive(:wait_until_ready)
    @agent_2.should_receive(:apply).with(IDLE_PLAN).and_return({
      "id" => "task-1",
      "state" => "done"
    })
    @agent_2.should_receive(:apply).with(BASIC_PLAN).and_return({
      "id" => "task-1",
      "state" => "done"
    })
    @agent_2.should_receive(:get_state).and_return(IDLE_STATE)
    @agent_2.should_receive(:get_state).and_return(BASIC_INSTANCE_STATE)
    @agent_2.should_receive(:start)

    instance_updater.update

    @instance.refresh
    vm = @instance.vm
    vm.cid.should == "vm-id-2"
    vm.agent_id.should == "agent-2"
    @instance.state.should == "started"
    Bosh::Director::Models::Vm.filter(:cid => "vm-id").first.should be_nil
  end

  it "should do a resource pool update with an existing disk" do
    Bosh::Director::Models::PersistentDisk.make(:disk_cid => "disk-id",
                                                :instance_id => @instance.id,
                                                :active => true)
    @instance.persistent_disk_cid.should == "disk-id"

    @agent_2 = mock("agent-2")
    @agent_2.stub!(:id).and_return("agent-2")
    Bosh::Director::AgentClient.stub!(:new).with("agent-2").and_return(@agent_2)
    Bosh::Director::VmCreator.stub(:generate_agent_id).and_return("agent-2")

    stub_object(@instance_spec,
                :resource_pool_changed? => true,
                :persistent_disk_changed? => false,
                :networks_changed? => false,
                :disk_currently_attached? => true,
                :dns_changed? => false,
                :changes => Set.new,
                :disk_size => 1024,
                :network_settings => BASIC_PLAN["networks"],
                :state => "started")

    instance_updater = Bosh::Director::InstanceUpdater.new(@instance_spec)
    instance_updater.stub!(:generate_agent_id).and_return("agent-2")
    instance_updater.stub!(:cloud).and_return(@cloud)

    @instance_spec.stub!(:spec).and_return(BASIC_PLAN)

    @agent_1.should_receive(:drain).with("shutdown").ordered.and_return(0.01)
    @agent_1.should_receive(:stop).ordered
    @agent_1.should_receive(:unmount_disk).with("disk-id").ordered.and_return({"state" => "done"})
    @cloud.should_receive(:detach_disk).with("vm-id", "disk-id").ordered

    @cloud.should_receive(:delete_vm).with("vm-id").ordered
    @cloud.should_receive(:create_vm).with("agent-2", "stemcell-id", BASIC_PLAN["resource_pool"]["cloud_properties"],
      BASIC_PLAN["networks"], ["disk-id"], {}).ordered.and_return("vm-id-2")
    @cloud.should_receive(:attach_disk).ordered.with("vm-id-2", "disk-id")

    @agent_2.should_receive(:wait_until_ready).ordered
    @agent_2.should_receive(:mount_disk).with("disk-id").ordered.and_return({"state" => "done"})
    @agent_2.should_receive(:list_disk).and_return(["disk-id"])

    @agent_2.should_receive(:apply).with(IDLE_PLAN.merge({"persistent_disk" => 1024})).ordered.and_return({
      "id" => "task-1",
      "state" => "done"
    })

    @agent_2.should_receive(:get_state).ordered.and_return(IDLE_STATE)
    @instance_spec.should_receive(:current_state=).with(IDLE_STATE).ordered

    @agent_2.should_receive(:apply).with(BASIC_PLAN).ordered.and_return({
      "id" => "task-1",
      "state" => "done"
    })

    @agent_2.should_receive(:start).ordered
    @agent_2.should_receive(:get_state).ordered.and_return(BASIC_INSTANCE_STATE)

    instance_updater.update

    @instance.refresh
    @instance.persistent_disk_cid.should == "disk-id"
    vm = @instance.vm
    vm.cid.should == "vm-id-2"
    vm.agent_id.should == "agent-2"
    Bosh::Director::Models::Vm.filter(:cid => "vm-id").first.should be_nil
  end

  it "should update the networks when needed" do
    stub_object(@instance_spec,
                :resource_pool_changed? => false,
                :persistent_disk_changed? => false,
                :networks_changed? => true,
                :dns_changed? => false,
                :changes => Set.new,
                :disk_currently_attached? => false,
                :network_settings =>BASIC_PLAN["networks"],
                :state => "started")

    instance_updater = Bosh::Director::InstanceUpdater.new(@instance_spec)
    instance_updater.stub!(:cloud).and_return(@cloud)

    @instance_spec.stub!(:spec).and_return(BASIC_PLAN)

    @agent_1.should_receive(:drain).with("shutdown").and_return(0.01)
    @agent_1.should_receive(:stop)
    @agent_1.should_receive(:prepare_network_change).with(BASIC_PLAN["networks"])
    @cloud.should_receive(:configure_networks).with("vm-id", BASIC_PLAN["networks"])
    @agent_1.should_receive(:wait_until_ready)
    @agent_1.should_receive(:apply).with(BASIC_PLAN).and_return({
      "id" => "task-1",
      "state" => "done"
    })
    @agent_1.should_receive(:get_state).and_return(BASIC_INSTANCE_STATE)
    @agent_1.should_receive(:start)

    instance_updater.update
  end

  it "should update the dns when needed" do
    stub_object(@instance_spec,
                :resource_pool_changed? => false,
                :persistent_disk_changed? => false,
                :networks_changed? => true,
                :dns_changed? => true,
                :changes => Set.new([:dns]),
                :disk_currently_attached? => false,
                :network_settings =>BASIC_PLAN["networks"],
                :state => "started")

    instance_updater = Bosh::Director::InstanceUpdater.new(@instance_spec)
    instance_updater.stub!(:cloud).and_return(@cloud)

    dns_domain = Bosh::Director::Models::Dns::Domain.make
    Bosh::Director::Models::Dns::Record.make(:domain => dns_domain, :name => "0.some.record", :content => "0.0.0.0")

    @instance_spec.stub!(:spec).and_return(BASIC_PLAN)
    dns_records = {"0.some.record" => "1.2.3.4", "0.some.other.record" => "5.6.7.8"}
    @instance_spec.stub!(:dns_records).and_return(dns_records)
    @deployment_plan.stub!(:dns_domain).and_return(dns_domain)

    instance_updater.update

    map = {}
    records = Bosh::Director::Models::Dns::Record.all
    records.size.should == 2
    records.each { |record| map[record.name] = record.content }
    map.should == dns_records
  end

  it "should create a persistent disk when needed" do
    stub_object(@instance_spec,
                :resource_pool_changed? => false,
                :persistent_disk_changed? => true,
                :disk_currently_attached? => false,
                :networks_changed? => false,
                :dns_changed? => false,
                :changes => Set.new,
                :state => "started")

    instance_updater = Bosh::Director::InstanceUpdater.new(@instance_spec)
    instance_updater.stub!(:cloud).and_return(@cloud)

    @instance_spec.stub!(:spec).and_return(BASIC_PLAN)

    @agent_1.should_receive(:drain).with("shutdown").and_return(0.01)
    @agent_1.should_receive(:stop)
    @cloud.should_receive(:create_disk).with(1024, "vm-id").and_return("disk-id")
    @cloud.should_receive(:attach_disk).with("vm-id", "disk-id")
    @agent_1.should_receive(:mount_disk).with("disk-id").and_return({"state" => "done"})
    @agent_1.should_receive(:apply).with(BASIC_PLAN).and_return({
      "id" => "task-1",
      "state" => "done"
    })

    @agent_1.should_receive(:get_state).and_return(BASIC_INSTANCE_STATE)
    @agent_1.should_receive(:start)

    instance_updater.update

    @instance.refresh
    @instance.vm.should == @vm.reload
    @instance.persistent_disk_cid.should == "disk-id"
  end

  it "should migrate a persistent disk when needed" do
    Bosh::Director::Models::PersistentDisk.make(:disk_cid => "old-disk-id",
                                                :instance_id => @instance.id,
                                                :active => true)

    stub_object(@instance_spec,
                :resource_pool_changed? => false,
                :persistent_disk_changed? => true,
                :disk_currently_attached? => true,
                :networks_changed? => false,
                :dns_changed? => false,
                :changes => Set.new,
                :state => "started")

    instance_updater = Bosh::Director::InstanceUpdater.new(@instance_spec)
    instance_updater.stub!(:cloud).and_return(@cloud)

    @instance_spec.stub!(:spec).and_return(BASIC_PLAN)

    @agent_1.should_receive(:drain).with("shutdown").and_return(0.01)
    @agent_1.should_receive(:stop)
    @cloud.should_receive(:create_disk).with(1024, "vm-id").and_return("disk-id")
    @cloud.should_receive(:attach_disk).with("vm-id", "disk-id")
    @agent_1.should_receive(:mount_disk).with("disk-id").and_return({"state" => "done"})
    @agent_1.should_receive(:migrate_disk).with("old-disk-id", "disk-id").and_return({
      "id" => "task-1",
      "state" => "done"
    })
    @agent_1.should_receive(:list_disk).and_return(["old-disk-id"])
    @agent_1.should_receive(:unmount_disk).with("old-disk-id").and_return({"state" => "done"})
    @cloud.should_receive(:detach_disk).with("vm-id", "old-disk-id")
    @cloud.should_receive(:delete_disk).with("old-disk-id")
    @agent_1.should_receive(:apply).with(BASIC_PLAN).and_return({
      "id" => "task-1",
      "state" => "done"
    })
    @agent_1.should_receive(:get_state).and_return(BASIC_INSTANCE_STATE)
    @agent_1.should_receive(:start)

    instance_updater.update

    @instance.refresh
    @instance.vm.should == @vm.reload
    @instance.persistent_disk_cid.should == "disk-id"
  end

  it "should delete a persistent disk when needed" do
    Bosh::Director::Models::PersistentDisk.make(:disk_cid => "old-disk-id", :instance_id => @instance.id)

    plan = BASIC_PLAN._deep_copy
    plan["persistent_disk"] = 0

    state = BASIC_INSTANCE_STATE._deep_copy
    state["persistent_disk"] = 0

    stub_object(@instance_spec,
                :resource_pool_changed? => false,
                :persistent_disk_changed? => true,
                :networks_changed? => false,
                :disk_currently_attached? => true,
                :dns_changed? => false,
                :changes => Set.new,
                :state => "started")

    @job_spec.stub!(:persistent_disk).and_return(plan["persistent_disk"])

    instance_updater = Bosh::Director::InstanceUpdater.new(@instance_spec)
    instance_updater.stub!(:cloud).and_return(@cloud)


    @instance_spec.stub!(:spec).and_return(plan)

    @agent_1.should_receive(:drain).with("shutdown").and_return(0.01)
    @agent_1.should_receive(:stop)
    @agent_1.should_receive(:list_disk).and_return(["old-disk-id"])
    @agent_1.should_receive(:unmount_disk).with("old-disk-id").and_return({"state" => "done"})
    @cloud.should_receive(:detach_disk).with("vm-id", "old-disk-id")
    @cloud.should_receive(:delete_disk).with("old-disk-id")
    @agent_1.should_receive(:apply).with(plan).and_return({
      "id" => "task-1",
      "state" => "done"
    })
    @agent_1.should_receive(:get_state).and_return(state)
    @agent_1.should_receive(:start)

    instance_updater.update

    @instance.refresh
    @instance.vm.should == @vm.reload
    @instance.persistent_disk_cid.should be_nil
  end

  # Previous state:
  # 1 - Create a persistentdisk with the new size (not-activated)
  # 2 - Agent fails while trying to migrate.
  it "keep track of persistent disk failed to migrate (agent error)" do
    stub_object(@instance_spec,
                :resource_pool_changed? => false,
                :persistent_disk_changed? => true,
                :disk_currently_attached? => true,
                :networks_changed? => false,
                :dns_changed? => false,
                :changes => Set.new,
                :state => "started")

    # good old disk
    Bosh::Director::Models::PersistentDisk.make(:disk_cid => "old-disk-id",
                                                :instance_id => @instance.id,
                                                :active => true,
                                                :size => 500)

    # bad new disk
    Bosh::Director::Models::PersistentDisk.make(:disk_cid => "new-disk-id",
                                                :instance_id => @instance.id,
                                                :active => false,
                                                :size => 1024)

    instance_updater = Bosh::Director::InstanceUpdater.new(@instance_spec)
    instance_updater.stub!(:cloud).and_return(@cloud)

    @instance_spec.stub!(:spec).and_return(BASIC_PLAN)

    @agent_1.should_receive(:drain).with("shutdown").and_return(0.01)
    @agent_1.should_receive(:stop)

    # simulating a case where the agent failed to mount
    # Agent still has the "old-disk-id" instead of "new-disk-id"
    @agent_1.should_receive(:list_disk).and_return(["old-disk-id"])

    # detach and remove old-disk-id
    @agent_1.should_receive(:unmount_disk).with("old-disk-id").and_return({"state" => "done"})
    @cloud.should_receive(:detach_disk).with("vm-id", "old-disk-id")
    @cloud.should_receive(:delete_disk).with("old-disk-id")

    # keep track of the failed disk.
    @cloud.should_not_receive(:delete_disk).with("new-disk-id")

    # create, attach, mount and migrate to new disk
    @cloud.should_receive(:create_disk).with(1024, "vm-id").and_return("disk-id")
    @cloud.should_receive(:attach_disk).with("vm-id", "disk-id")
    @agent_1.should_receive(:mount_disk).with("disk-id").and_return({"state" => "done"})
    @agent_1.should_receive(:migrate_disk).with("old-disk-id", "disk-id").and_return({
      "id" => "task-1",
      "state" => "done"
    })
    @agent_1.should_receive(:apply).with(BASIC_PLAN).and_return({
      "id" => "task-1",
      "state" => "done"
    })
    @agent_1.should_receive(:get_state).and_return(BASIC_INSTANCE_STATE)
    @agent_1.should_receive(:start)

    instance_updater.update

    @instance.refresh
    @instance.vm.should == @vm.reload
    @instance.persistent_disk_cid.should == "disk-id"
  end

  # Previous state:
  # 1 - Create a persistent disk with the new size (not-activated)
  # 2 - Agent migrate is successful
  # 3 - We fail to activate the disk created in -1-
  it "fail if director and agent are not in agreement in terms of persistent disks" do
    stub_object(@instance_spec,
                :resource_pool_changed? => false,
                :persistent_disk_changed? => false,
                :disk_currently_attached? => true,
                :networks_changed? => false,
                :dns_changed? => false,
                :changes => Set.new,
                :state => "started")

    Bosh::Director::Models::PersistentDisk.make(:disk_cid => "old-disk-id",
                                                :instance_id => @instance.id,
                                                :active => true,
                                                :size => 500)
    Bosh::Director::Models::PersistentDisk.make(:disk_cid => "new-disk-id",
                                                :instance_id => @instance.id,
                                                :active => false,
                                                :size => 1024)

    instance_updater = Bosh::Director::InstanceUpdater.new(@instance_spec)
    instance_updater.stub!(:cloud).and_return(@cloud)

    @instance_spec.stub!(:spec).and_return(BASIC_PLAN)

    @agent_1.should_receive(:drain).with("update", BASIC_PLAN).ordered.and_return(0.01)
    @agent_1.should_receive(:stop)

    # the agent already has the new disk
    @agent_1.should_receive(:list_disk).and_return(["new-disk-id"])

    # keep the new-disk
    @cloud.should_not_receive(:detach_disk).with("vm-id", "new-disk-id")
    @cloud.should_not_receive(:delete_disk).with("new-disk-id")

    # We failed to activate the director's db entry. Agent and Director have
    # different persistent disks info => raise an exception
    lambda {
      instance_updater.update
    }.should raise_error(BD::AgentDiskOutOfSync)

    @instance.refresh
    @instance.vm.should == @vm
  end

  # Previous state:
  # 1 - Create a persistent disk with new size (not-activated)
  # 2 - Agent migrate is successful
  # 3 - successfully activate disk created in -1-
  # 4 - We fail to push the new disk-size to the agent ("apply_state").
  it "should recover from apply_state error while migrating disks" do
    stub_object(@instance_spec,
                :resource_pool_changed? => false,
                :persistent_disk_changed? => false,
                :disk_currently_attached? => true,
                :networks_changed? => false,
                :dns_changed? => false,
                :changes => Set.new,
                :state => "started")

    Bosh::Director::Models::PersistentDisk.make(:disk_cid => "disk-id",
                                                :instance_id => @instance.id,
                                                :active => true,
                                                :size => 1024)

    instance_updater = Bosh::Director::InstanceUpdater.new(@instance_spec)
    instance_updater.stub!(:cloud).and_return(@cloud)

    @instance_spec.stub!(:spec).and_return(BASIC_PLAN)

    @agent_1.should_receive(:drain).with("update", BASIC_PLAN).ordered.and_return(0.01)
    @agent_1.should_receive(:stop)

    # the agent already has the new disk
    @agent_1.should_receive(:list_disk).and_return(["disk-id"])

    # We should leave the disk.
    @cloud.should_not_receive(:detach_disk)
    @cloud.should_not_receive(:delete_disk)

    # Everything went ok execpt the last 'apply_state' call. Agent and Director
    # are in agreement. Thus the only thing left to do is to do the last apply
    # state.
    @agent_1.should_receive(:apply).with(BASIC_PLAN).and_return({
      "id" => "task-1",
      "state" => "done"
    })
    @agent_1.should_receive(:get_state).and_return(BASIC_INSTANCE_STATE)
    @agent_1.should_receive(:start)

    instance_updater.update

    @instance.refresh
    @instance.vm.should == @vm.reload
    @instance.persistent_disk_cid.should == "disk-id"
  end

  describe "instance state transitions" do

    def done_task(id = "task-1")
      { "id" => id, "state" => "done" }
    end

    it "transition to started" do
      @instance_spec.stub!(:resource_pool_changed? => false,
                           :persistent_disk_changed? => false,
                           :networks_changed? => false,
                           :disk_currently_attached? => false,
                           :dns_changed? => false,
                           :changes => Set.new,
                           :state => "started",
                           :spec => BASIC_PLAN)

      updater = make_updater(@instance_spec)

      @agent_1.should_receive(:drain).with("update", BASIC_PLAN).ordered.and_return(0.01)
      @agent_1.should_receive(:stop).ordered
      @agent_1.should_receive(:apply).with(BASIC_PLAN).ordered.and_return(done_task)
      @agent_1.should_receive(:start).ordered
      @agent_1.should_receive(:get_state).ordered.and_return(BASIC_INSTANCE_STATE)

      updater.update
      @instance.refresh
      @instance.vm.should_not be_nil
    end

    it "transition to stopped" do
      @instance_spec.stub!(:resource_pool_changed? => false,
                           :persistent_disk_changed? => false,
                           :networks_changed? => false,
                           :disk_currently_attached? => false,
                           :dns_changed? => false,
                           :changes => Set.new,
                           :state => "stopped",
                           :spec => BASIC_PLAN)

      updater = make_updater(@instance_spec)

      @agent_1.should_receive(:drain).with("shutdown").and_return(0.01)
      @agent_1.should_receive(:stop)
      @agent_1.should_receive(:apply).with(BASIC_PLAN).and_return(done_task)
      @agent_1.should_receive(:get_state).and_return(BASIC_INSTANCE_STATE.merge("job_state" => "stopped"))
      @agent_1.should_not_receive(:start)

      updater.update
      @instance.refresh
      @instance.vm.should_not be_nil
    end

    it "transition to detached" do
      Bosh::Director::Models::PersistentDisk.make(:disk_cid => "deadbeef", :instance_id => @instance.id)

      @instance_spec.stub!(:resource_pool_changed? => false,
                           :persistent_disk_changed? => false,
                           :networks_changed? => false,
                           :disk_currently_attached? => true,
                           :dns_changed? => false,
                           :changes => Set.new,
                           :state => "detached",
                           :spec => BASIC_PLAN)

      updater = make_updater(@instance_spec)

      @agent_1.should_receive(:drain).with("shutdown").ordered.and_return(0.01)
      @agent_1.should_receive(:stop).ordered
      @agent_1.should_receive(:unmount_disk).with("deadbeef").ordered.and_return(done_task)
      @cloud.should_receive(:detach_disk).with("vm-id", "deadbeef").ordered
      @cloud.should_receive(:delete_vm).with("vm-id").ordered
      @resource_pool_spec.should_receive(:add_idle_vm).ordered

      updater.update
      @instance.refresh
      @instance.persistent_disk_cid.should == "deadbeef"
      @instance.vm.should be_nil
    end
  end

  describe "watch time schedule" do
    it "can generate a schedule for min and max watch time" do
      @instance_spec.stub!(:state => "started")
      updater = make_updater(@instance_spec)

      updater.watch_schedule(5000, 10000, 5).should == [5000, 1000, 1000, 1000, 1000, 1000]
      updater.watch_schedule(5000, 11000, 3).should == [5000, 2000, 2000, 2000]
      updater.watch_schedule(5000, 10000, 10).should == [5000, 1000, 1000, 1000, 1000, 1000]
      updater.watch_schedule(1000, 100000, 3).should == [1000, 33000, 33000, 33000]
      updater.watch_schedule(2000, 15000, 2).should == [2000, 6500, 6500]
    end
  end
end
