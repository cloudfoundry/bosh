# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

BOSH_STEMCELL_TGZ ||= "bosh-instance-1.0.tgz"

describe Bosh::Deployer::InstanceManager do
  before(:each) do
    @dir = Dir.mktmpdir("bdim_spec")
    @config = YAML.load_file(spec_asset("test-bootstrap-config.yml"))
    @config["dir"] = @dir
    @config["name"] = "spec-#{UUIDTools::UUID.random_create.to_s}"
    @config["logging"] = { "file" => "#{@dir}/bmim.log" }
    @deployer = Bosh::Deployer::InstanceManager.create(@config)
    @cloud = mock("cloud")
    Bosh::Deployer::Config.stub!(:cloud).and_return(@cloud)
    @agent = mock("agent")
    Bosh::Deployer::Config.stub!(:agent).and_return(@agent)
  end

  after(:each) do
    @deployer.state.destroy
    FileUtils.remove_entry_secure @dir
  end

  def load_deployment
    @deployer.send(:load_deployments)["instances"].select { |d| d[:name] == @deployer.state.name }.first
  end

  it "should update the apply spec" do
    spec = YAML.load_file(spec_asset("apply_spec.yml"))
    @deployer.update_spec(spec)
    props = spec["properties"]

    %w{blobstore postgres director redis nats}.each do |service|
      ip = props[service]["address"]
      ip.should_not be_nil
      ip.should_not == "127.0.0.1"
      ip.should == Bosh::Deployer::Config.networks["bosh"]["ip"]
    end

    cloud_options = Bosh::Deployer::Config.cloud_options
    case cloud_options["plugin"]
    when "vsphere"
      props["vcenter"]["address"].should_not == "127.0.0.1"
      props["vcenter"]["address"].should == cloud_options["properties"]["vcenters"].first["host"]
      props["vcenter"]["user"].should_not == "vcenter-user"
      props["vcenter"]["password"].should_not == "vcenter-password"
    else
    end
  end

  it "should override the apply spec with properties" do
    spec = YAML.load_file(spec_asset("apply_spec.yml"))

    properties = YAML.load_file(spec_asset("test-apply-spec-properties.yml"))

    Bosh::Deployer::Config.spec_properties.merge!(properties["apply_spec"]["properties"])

    @deployer.update_spec(spec)
    props = spec["properties"]

    %w{blobstore postgres director redis nats}.each do |service|
      ip = props[service]["address"]
      ip.should_not be_nil
      ip.should_not == "127.0.0.1"
      if override = Bosh::Deployer::Config.spec_properties[service]
        expected_ip = override["address"]
      end
      expected_ip ||= Bosh::Deployer::Config.networks["bosh"]["ip"]
      ip.should == expected_ip
    end

    cloud_options = Bosh::Deployer::Config.cloud_options
    case cloud_options["plugin"]
    when "vsphere"
      props["vcenter"]["address"].should == "devNN"
      props["vcenter"]["address"].should_not == cloud_options["properties"]["vcenters"].first["host"]
      props["vcenter"]["user"].should == "devNN-user"
      props["vcenter"]["password"].should == "devNN-password"
    else
    end
  end

  it "should apply" do
    spec = YAML.load_file(spec_asset("apply_spec.yml"))
    updated_spec = @deployer.update_spec(spec.dup)
    @agent.should_receive(:run_task).with(:stop)
    @agent.should_receive(:run_task).with(:apply, updated_spec)
    @agent.should_receive(:run_task).with(:start)
    @deployer.apply(spec)
  end

  it "should populate disk model" do
    disk_model = @deployer.disk_model
    disk_model.should == VSphereCloud::Models::Disk
    disk_model.columns.should include(:id)
    disk_model.count.should == 0
    cid = 22
    disk_model.insert({:id => cid, :size => 1024})
    disk_model.count.should == 1
    disk_model[cid].destroy
    disk_model.count.should == 0
  end

  it "should create a Bosh instance" do
    spec = YAML.load_file(spec_asset("apply_spec.yml"))
    @deployer.stub!(:run_command)
    @deployer.stub!(:wait_until_agent_ready)
    @deployer.stub!(:wait_until_director_ready)
    @deployer.stub!(:load_apply_spec).and_return(spec)

    @deployer.state.uuid.should_not be_nil

    @deployer.state.stemcell_cid.should be_nil
    @deployer.state.vm_cid.should be_nil

    @cloud.should_receive(:create_stemcell).and_return("SC-CID-CREATE")
    @cloud.should_receive(:create_vm).and_return("VM-CID-CREATE")
    @cloud.should_receive(:create_disk).and_return("DISK-CID-CREATE")
    @cloud.should_receive(:attach_disk).with("VM-CID-CREATE", "DISK-CID-CREATE")
    @agent.should_receive(:run_task).with(:mount_disk, "DISK-CID-CREATE").and_return({})
    @agent.should_receive(:run_task).with(:stop)
    @agent.should_receive(:run_task).with(:apply, spec)
    @agent.should_receive(:run_task).with(:start)

    @deployer.create(BOSH_STEMCELL_TGZ)

    @deployer.state.stemcell_cid.should == "SC-CID-CREATE"
    @deployer.state.vm_cid.should == "VM-CID-CREATE"
    @deployer.state.disk_cid.should == "DISK-CID-CREATE"
    load_deployment.should == @deployer.state.values

    @deployer.renderer.total.should == @deployer.renderer.index
  end

  it "should destroy a Bosh instance" do
    disk_cid = "33"
    @deployer.state.disk_cid = disk_cid
    @deployer.state.stemcell_name = File.basename(BOSH_STEMCELL_TGZ, ".tgz")
    @deployer.state.stemcell_cid = "SC-CID-DESTROY"
    @deployer.state.vm_cid = "VM-CID-DESTROY"

    @agent.should_receive(:list_disk).and_return([disk_cid])
    @agent.should_receive(:run_task).with(:stop)
    @agent.should_receive(:run_task).with(:unmount_disk, disk_cid).and_return({})
    @cloud.should_receive(:detach_disk).with("VM-CID-DESTROY", disk_cid)
    @cloud.should_receive(:delete_disk).with(disk_cid)
    @cloud.should_receive(:delete_vm).with("VM-CID-DESTROY")
    @cloud.should_receive(:delete_stemcell).with("SC-CID-DESTROY")

    @deployer.destroy

    @deployer.state.stemcell_cid.should be_nil
    @deployer.state.vm_cid.should be_nil
    @deployer.state.disk_cid.should be_nil

    load_deployment.should == @deployer.state.values

    @deployer.renderer.total.should == @deployer.renderer.index
  end

  it "should update a Bosh instance" do
    spec = YAML.load_file(spec_asset("apply_spec.yml"))
    disk_cid = "22"
    @deployer.stub!(:run_command)
    @deployer.stub!(:wait_until_agent_ready)
    @deployer.stub!(:wait_until_director_ready)
    @deployer.stub!(:load_apply_spec).and_return(spec)

    @deployer.state.stemcell_cid = "SC-CID-UPDATE"
    @deployer.state.vm_cid = "VM-CID-UPDATE"
    @deployer.state.disk_cid = disk_cid

    @agent.should_receive(:run_task).with(:stop)
    @agent.should_receive(:run_task).with(:unmount_disk, disk_cid).and_return({})
    @cloud.should_receive(:detach_disk).with("VM-CID-UPDATE", disk_cid)
    @cloud.should_receive(:delete_vm).with("VM-CID-UPDATE")
    @cloud.should_receive(:delete_stemcell).with("SC-CID-UPDATE")
    @cloud.should_receive(:create_stemcell).and_return("SC-CID")
    @cloud.should_receive(:create_vm).and_return("VM-CID")
    @cloud.should_receive(:attach_disk).with("VM-CID", disk_cid)
    @agent.should_receive(:run_task).with(:mount_disk, disk_cid).and_return({})
    @agent.should_receive(:list_disk).and_return([disk_cid])
    @agent.should_receive(:run_task).with(:stop)
    @agent.should_receive(:run_task).with(:apply, spec)
    @agent.should_receive(:run_task).with(:start)

    @deployer.update(BOSH_STEMCELL_TGZ)

    @deployer.state.stemcell_cid.should == "SC-CID"
    @deployer.state.vm_cid.should == "VM-CID"
    @deployer.state.disk_cid.should == disk_cid

    load_deployment.should == @deployer.state.values
  end

  it "should fail to create a Bosh instance if stemcell CID exists" do
    @deployer.state.stemcell_cid = "SC-CID"

    lambda {
      @deployer.create(BOSH_STEMCELL_TGZ)
    }.should raise_error(Bosh::Deployer::ConfigError)
  end

  it "should fail to create a Bosh instance if VM CID exists" do
    @deployer.state.vm_cid = "VM-CID"

    lambda {
      @deployer.create(BOSH_STEMCELL_TGZ)
    }.should raise_error(Bosh::Deployer::ConfigError)
  end

  it "should fail to destroy a Bosh instance unless stemcell CID exists" do
    @deployer.state.vm_cid = "VM-CID"
    @agent.should_receive(:run_task).with(:stop)
    @cloud.should_receive(:delete_vm).with("VM-CID")
    lambda {
      @deployer.destroy
    }.should raise_error(Bosh::Deployer::ConfigError)
  end

  it "should fail to destroy a Bosh instance unless VM CID exists" do
    @deployer.state.stemcell_cid = "SC-CID"
    @agent.should_receive(:run_task).with(:stop)
    lambda {
      @deployer.destroy
    }.should raise_error(Bosh::Deployer::ConfigError)
  end

end
