require File.dirname(__FILE__) + '/../spec_helper'

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

  before(:each) do
    @deployment = Bosh::Director::Models::Deployment.make
    @vm = Bosh::Director::Models::Vm.make(:deployment => @deployment, :agent_id => "agent-1", :cid => "vm-id")
    @instance = Bosh::Director::Models::Instance.make(:deployment => @deployment, :vm => @vm, :disk_cid => nil)
    @stemcell = Bosh::Director::Models::Stemcell.make(:cid => "stemcell-id")

    @cloud = mock("cloud")
    @agent_1 = mock("agent-1")
    @instance_spec = mock("instance_spec")
    @job_spec = mock("job_spec")
    @deployment_plan = mock("deployment_plan")
    @resource_pool_spec = mock("resource_pool_spec")
    @update_spec = mock("update_spec")
    @stemcell_spec = mock("stemcell_spec")
    @release_spec = mock("release_spec")

    @instance_spec.stub!(:job).and_return(@job_spec)
    @instance_spec.stub!(:instance).and_return(@instance)

    @job_spec.stub!(:deployment).and_return(@deployment_plan)
    @job_spec.stub!(:resource_pool).and_return(@resource_pool_spec)
    @job_spec.stub!(:update).and_return(@update_spec)
    @job_spec.stub!(:name).and_return("test_job")
    @job_spec.stub!(:package_spec).and_return(BASIC_PLAN["packages"])
    @job_spec.stub!(:persistent_disk).and_return(BASIC_PLAN["persistent_disk"])
    @job_spec.stub!(:properties).and_return(BASIC_PLAN["properties"])
    @job_spec.stub!(:spec).and_return(BASIC_PLAN["job"])

    @update_spec.stub!(:update_watch_time).and_return(0.01)

    @release_spec.stub!(:name).and_return("test_release")
    @release_spec.stub!(:version).and_return(99)
    @release_spec.stub!(:spec).and_return({"name" => "test_release", "version" => 99})

    @deployment_plan.stub!(:resource_pool).with("small").and_return(@resource_pool_spec)
    @deployment_plan.stub!(:deployment).and_return(@deployment)
    @deployment_plan.stub!(:name).and_return("test_deployment")
    @deployment_plan.stub!(:release).and_return(@release_spec)

    @resource_pool_spec.stub!(:stemcell).and_return(@stemcell_spec)
    @resource_pool_spec.stub!(:spec).and_return(BASIC_PLAN["resource_pool"])
    @resource_pool_spec.stub!(:cloud_properties).and_return(BASIC_PLAN["resource_pool"]["cloud_properties"])
    @resource_pool_spec.stub!(:env).and_return({})

    @stemcell_spec.stub!(:stemcell).and_return(@stemcell)

    Bosh::Director::Config.stub!(:cloud).and_return(@cloud)

    @agent_1.stub!(:id).and_return("agent-1")
    Bosh::Director::AgentClient.stub!(:new).with("agent-1").and_return(@agent_1)
  end

  it "should do a basic update" do
    stub_object(@instance_spec, :resource_pool_changed? => false,
                                :persistent_disk_changed? => false,
                                :networks_changed? => false)

    instance_updater = Bosh::Director::InstanceUpdater.new(@instance_spec)

    @instance_spec.stub!(:spec).and_return(BASIC_PLAN)

    @agent_1.should_receive(:drain).with("update", BASIC_PLAN).and_return(0.01)
    @agent_1.should_receive(:stop)
    @agent_1.should_receive(:apply).with(BASIC_PLAN).and_return({
      "id" => "task-1",
      "state" => "done"
    })
    @agent_1.should_receive(:get_state).and_return(BASIC_INSTANCE_STATE)

    instance_updater.update
  end

  it "should do a basic canary update" do
    stub_object(@instance_spec, :resource_pool_changed? => false,
                                :persistent_disk_changed? => false,
                                :networks_changed? => false)

    instance_updater = Bosh::Director::InstanceUpdater.new(@instance_spec)

    @instance_spec.stub!(:spec).and_return(BASIC_PLAN)

    @update_spec.should_not_receive(:update_watch_time)
    @update_spec.should_receive(:canary_watch_time).and_return(0.01)

    @agent_1.should_receive(:drain).with("update", BASIC_PLAN).and_return(0.01)
    @agent_1.should_receive(:stop)
    @agent_1.should_receive(:apply).with(BASIC_PLAN).and_return({
      "id" => "task-1",
      "state" => "done"
    })
    @agent_1.should_receive(:get_state).and_return(BASIC_INSTANCE_STATE)

    instance_updater.update(:canary => true)
  end

  it "should do a resource pool update" do
    @agent_2 = mock("agent-2")
    @agent_2.stub!(:id).and_return("agent-2")
    Bosh::Director::AgentClient.stub!(:new).with("agent-2").and_return(@agent_2)

    stub_object(@instance_spec, :resource_pool_changed? => true,
                                :persistent_disk_changed? => false,
                                :networks_changed? => false,
                                :network_settings => BASIC_PLAN["networks"])

    @instance_spec.should_receive(:current_state=).with(IDLE_STATE)
    @instance_spec.should_receive(:current_state).and_return(IDLE_STATE)

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

    instance_updater.update

    @instance.refresh
    vm = @instance.vm
    vm.cid.should == "vm-id-2"
    vm.agent_id.should == "agent-2"
    Bosh::Director::Models::Vm.filter(:cid => "vm-id").first.should be_nil
  end

  it "should do a resource pool update with an existing disk" do
    @instance.disk_cid = "disk-id"
    @instance.save

    @agent_2 = mock("agent-2")
    @agent_2.stub!(:id).and_return("agent-2")
    Bosh::Director::AgentClient.stub!(:new).with("agent-2").and_return(@agent_2)

    stub_object(@instance_spec, :resource_pool_changed? => true,
                                :persistent_disk_changed? => false,
                                :networks_changed? => false,
                                :network_settings => BASIC_PLAN["networks"])

    @instance_spec.should_receive(:current_state=).with(IDLE_STATE)
    @instance_spec.should_receive(:current_state).and_return(IDLE_STATE.merge({"persistent_disk" => "1gb"}))

    instance_updater = Bosh::Director::InstanceUpdater.new(@instance_spec)
    instance_updater.stub!(:generate_agent_id).and_return("agent-2")
    instance_updater.stub!(:cloud).and_return(@cloud)

    @instance_spec.stub!(:spec).and_return(BASIC_PLAN)

    @agent_1.should_receive(:drain).with("shutdown").and_return(0.01)
    @agent_1.should_receive(:stop)
    @agent_1.should_receive(:unmount_disk).with("disk-id").and_return({"state" => "done"})
    @cloud.should_receive(:detach_disk).with("vm-id", "disk-id")
    @cloud.should_receive(:delete_vm).with("vm-id")
    @cloud.should_receive(:create_vm).with("agent-2", "stemcell-id", BASIC_PLAN["resource_pool"]["cloud_properties"],
      BASIC_PLAN["networks"], ["disk-id"], {}).and_return("vm-id-2")
    @cloud.should_receive(:attach_disk).with("vm-id-2", "disk-id")

    @agent_2.should_receive(:wait_until_ready)
    @agent_2.should_receive(:apply).with(IDLE_PLAN.merge({"persistent_disk" => "1gb"})).and_return({
      "id" => "task-1",
      "state" => "done"
    })
    @agent_2.should_receive(:mount_disk).with("disk-id").and_return({"state" => "done"})
    @agent_2.should_receive(:apply).with(BASIC_PLAN).and_return({
      "id" => "task-1",
      "state" => "done"
    })
    @agent_2.should_receive(:get_state).and_return(IDLE_STATE)
    @agent_2.should_receive(:get_state).and_return(BASIC_INSTANCE_STATE)

    instance_updater.update

    @instance.refresh
    @instance.disk_cid.should == "disk-id"
    vm = @instance.vm
    vm.cid.should == "vm-id-2"
    vm.agent_id.should == "agent-2"
    Bosh::Director::Models::Vm.filter(:cid => "vm-id").first.should be_nil
  end

  it "should update the networks when needed" do
    stub_object(@instance_spec, :resource_pool_changed? => false,
                                :persistent_disk_changed? => false,
                                :networks_changed? => true,
                                :network_settings =>BASIC_PLAN["networks"])

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

    instance_updater.update
  end

  it "should create a persistent disk when needed" do
    stub_object(@instance_spec, :resource_pool_changed? => false,
                                :persistent_disk_changed? => true,
                                :networks_changed? => false)

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

    instance_updater.update

    @instance.refresh
    @instance.vm.should == @vm
    @instance.disk_cid.should == "disk-id"
  end

  it "should migrate a persistent disk when needed" do
    @instance.disk_cid = "old-disk-id"
    @instance.save

    stub_object(@instance_spec, :resource_pool_changed? => false,
                                :persistent_disk_changed? => true,
                                :networks_changed? => false)

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
    @agent_1.should_receive(:unmount_disk).with("old-disk-id").and_return({"state" => "done"})
    @cloud.should_receive(:detach_disk).with("vm-id", "old-disk-id")
    @cloud.should_receive(:delete_disk).with("old-disk-id")
    @agent_1.should_receive(:apply).with(BASIC_PLAN).and_return({
      "id" => "task-1",
      "state" => "done"
    })
    @agent_1.should_receive(:get_state).and_return(BASIC_INSTANCE_STATE)

    instance_updater.update

    @instance.refresh
    @instance.vm.should == @vm
    @instance.disk_cid.should == "disk-id"
  end

  it "should delete a persistent disk when needed" do
    @instance.disk_cid = "old-disk-id"
    @instance.save

    plan = BASIC_PLAN._deep_copy
    plan["persistent_disk"] = 0

    state = BASIC_INSTANCE_STATE._deep_copy
    state["persistent_disk"] = 0

    stub_object(@instance_spec, :resource_pool_changed? => false,
                                :persistent_disk_changed? => true,
                                :networks_changed? => false)

    @job_spec.stub!(:persistent_disk).and_return(plan["persistent_disk"])

    instance_updater = Bosh::Director::InstanceUpdater.new(@instance_spec)
    instance_updater.stub!(:cloud).and_return(@cloud)

    @instance_spec.stub!(:spec).and_return(plan)

    @agent_1.should_receive(:drain).with("shutdown").and_return(0.01)
    @agent_1.should_receive(:stop)
    @agent_1.should_receive(:unmount_disk).with("old-disk-id").and_return({"state" => "done"})
    @cloud.should_receive(:detach_disk).with("vm-id", "old-disk-id")
    @cloud.should_receive(:delete_disk).with("old-disk-id")
    @agent_1.should_receive(:apply).with(plan).and_return({
      "id" => "task-1",
      "state" => "done"
    })
    @agent_1.should_receive(:get_state).and_return(state)

    instance_updater.update

    @instance.refresh
    @instance.vm.should == @vm
    @instance.disk_cid.should be_nil
  end

end
