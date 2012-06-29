# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::ProblemHandlers::UnresponsiveAgent do

  def make_handler(vm, cloud, agent, data = {})
    handler = Bosh::Director::ProblemHandlers::UnresponsiveAgent.new(vm.id, data)
    handler.stub!(:cloud).and_return(cloud)
    Bosh::Director::AgentClient.stub!(:new).with(vm.agent_id, anything).and_return(agent)
    handler
  end

  before(:each) do
    @cloud = mock("cloud")
    @agent = mock("agent")
    Bosh::Director::Config.stub!(:cloud).and_return(@cloud)

    @vm = Bosh::Director::Models::Vm.make(:cid => "vm-cid")
    @instance =
      Bosh::Director::Models::Instance.make(:job => "mysql_node",
                                            :index => 0, :vm_id => @vm.id)
  end

  let :handler do
    make_handler(@vm, @cloud, @agent)
  end

  it "registers under unresponsive_agent type" do
    handler =
      Bosh::Director::ProblemHandlers::Base.create_by_type(:unresponsive_agent,
                                                           @vm.id, {})
    handler.should be_kind_of(Bosh::Director::ProblemHandlers::UnresponsiveAgent)
  end

  it "has well-formed description" do
    handler.description.should == "mysql_node/0 (vm-cid) is not responding"
  end

  describe "reboot_vm resolution" do
    it "skips reboot if CID is not present" do
      @vm.update(:cid => nil)
      @agent.should_receive(:ping).and_raise(Bosh::Director::RpcTimeout)
      lambda {
        handler.apply_resolution(:reboot_vm)
      }.should raise_error(Bosh::Director::ProblemHandlerError,
                           /doesn't have a cloud id/)
    end

    it "skips reboot if agent is now alive" do
      @agent.should_receive(:ping).and_return(:pong)

      lambda {
        handler.apply_resolution(:reboot_vm)
      }.should raise_error(Bosh::Director::ProblemHandlerError,
                           "Agent is responding now, skipping resolution")
    end

    it "reboots VM" do
      @agent.should_receive(:ping).and_raise(Bosh::Director::RpcTimeout)
      @cloud.should_receive(:reboot_vm).with("vm-cid")
      @agent.should_receive(:wait_until_ready)

      handler.apply_resolution(:reboot_vm)
    end

    it "reboots VM and whines if it is still unresponsive" do
      @agent.should_receive(:ping).and_raise(Bosh::Director::RpcTimeout)
      @cloud.should_receive(:reboot_vm).with("vm-cid")
      @agent.should_receive(:wait_until_ready).
        and_raise(Bosh::Director::RpcTimeout)

      lambda {
        handler.apply_resolution(:reboot_vm)
      }.should raise_error(Bosh::Director::ProblemHandlerError,
                           "Agent still unresponsive after reboot")
    end
  end

  describe "recreate_vm resolution" do

    it "skips recreate if CID is not present" do
      @vm.update(:cid => nil)
      @agent.should_receive(:ping).and_raise(Bosh::Director::RpcTimeout)
      lambda {
        handler.apply_resolution(:recreate_vm)
      }.should raise_error(Bosh::Director::ProblemHandlerError,
                           /doesn't have a cloud id/)
    end

    it "doesn't recreate VM if agent is now alive" do
      @agent.should_receive(:ping).and_return(:pong)

      lambda {
        handler.apply_resolution(:recreate_vm)
      }.should raise_error(Bosh::Director::ProblemHandlerError,
                           "Agent is responding now, skipping resolution")
    end

    it "doesn't recreate VM if apply spec is unknown" do
      @agent.should_receive(:ping).and_raise(Bosh::Director::RpcTimeout)
      lambda {
        handler.apply_resolution(:recreate_vm)
      }.should raise_error(Bosh::Director::ProblemHandlerError,
                           "Unable to look up VM apply spec")
    end

    it "whines on invalid spec format" do
      @vm.update(:apply_spec => "foobar")
      handler = make_handler(@vm, @cloud, @agent)
      @agent.should_receive(:ping).and_raise(Bosh::Director::RpcTimeout)

      lambda {
        handler.apply_resolution(:recreate_vm)
      }.should raise_error(Bosh::Director::ProblemHandlerError,
                           "Invalid apply spec format")
    end

    it "whines when stemcell is not in apply spec" do
      @vm.update(:apply_spec => { "resource_pool" => { "stemcell" => { "name" => "foo" } }}) # no version
      handler = make_handler(@vm, @cloud, @agent)
      @agent.should_receive(:ping).and_raise(Bosh::Director::RpcTimeout)

      lambda {
        handler.apply_resolution(:recreate_vm)
      }.should raise_error(Bosh::Director::ProblemHandlerError,
                           "Unknown stemcell name and/or version")
    end

    it "whines when stemcell is not in DB" do
      spec = {
        "resource_pool" => {
          "stemcell" => {
            "name" => "bosh-stemcell",
            "version" => "3.0.2"
          }
        }
      }

      @vm.update(:apply_spec => spec)
      handler = make_handler(@vm, @cloud, @agent)
      @agent.should_receive(:ping).and_raise(Bosh::Director::RpcTimeout)

      lambda {
        handler.apply_resolution(:recreate_vm)
      }.should raise_error(Bosh::Director::ProblemHandlerError,
                           "Unable to find stemcell `bosh-stemcell 3.0.2'")
    end

    it "recreates VM (w/persistent disk)" do
      spec = {
        "resource_pool" => {
          "stemcell" => {
            "name" => "bosh-stemcell",
            "version" => "3.0.2"
          },
          "cloud_properties" => { "foo" => "bar" },
          "env" => { "key1" => "value1" }
        },
        "networks" => ["A", "B", "C"]
      }
      Bosh::Director::VmCreator.stub(:generate_agent_id).and_return("agent-222")

      disk = Bosh::Director::Models::PersistentDisk.make(:disk_cid => "disk-cid", :instance_id => @instance.id)
      stemcell = Bosh::Director::Models::Stemcell.make(:name => "bosh-stemcell", :version => "3.0.2", :cid => "sc-302")

      # SQLite resets autoincrement id when table becomes empty,
      # so having this dummy record VM allows us to distinguish
      # between deleted VM and new VM (otherwise the'll have same id)
      dummy_vm = Bosh::Director::Models::Vm.make
      @vm.update(:apply_spec => spec)

      handler = make_handler(@vm, @cloud, @agent)
      handler.stub!(:generate_agent_id).and_return("agent-222")

      @agent.should_receive(:ping).and_raise(Bosh::Director::RpcTimeout)

      new_agent = mock("agent")

      @cloud.should_receive(:detach_disk).with("vm-cid", "disk-cid").ordered
      @cloud.should_receive(:delete_vm).with("vm-cid").ordered
      @cloud.should_receive(:create_vm).
        with("agent-222", "sc-302", { "foo" => "bar"}, ["A", "B", "C"], ["disk-cid"], { "key1" => "value1" }).
        ordered.and_return("new-vm-cid")

      Bosh::Director::AgentClient.stub!(:new).with("agent-222", anything).and_return(new_agent)
      @cloud.should_receive(:attach_disk).with("new-vm-cid", "disk-cid").ordered

      new_agent.should_receive(:wait_until_ready).ordered
      new_agent.should_receive(:mount_disk).with("disk-cid").ordered
      new_agent.should_receive(:apply).with(spec).ordered
      new_agent.should_receive(:start).ordered

      handler.apply_resolution(:recreate_vm)

      lambda {
        @vm.reload
      }.should raise_error(Sequel::Error, "Record not found")

      @instance.reload
      @instance.vm.apply_spec.should == spec
      @instance.vm.cid.should == "new-vm-cid"
      @instance.vm.agent_id.should == "agent-222"
      @instance.persistent_disk.disk_cid.should == "disk-cid"
    end

    it "recreates VM (no persistent disk)" do
      spec = {
        "resource_pool" => {
          "stemcell" => {
            "name" => "bosh-stemcell",
            "version" => "3.0.2"
          },
          "cloud_properties" => { "foo" => "bar" },
          "env" => { "key1" => "value1" }
        },
        "networks" => ["A", "B", "C"]
      }
      Bosh::Director::VmCreator.stub(:generate_agent_id).and_return("agent-222")

      stemcell = Bosh::Director::Models::Stemcell.make(:name => "bosh-stemcell", :version => "3.0.2", :cid => "sc-302")
      @vm.update(:apply_spec => spec)

      handler = make_handler(@vm, @cloud, @agent)
      handler.stub!(:generate_agent_id).and_return("agent-222")

      @agent.should_receive(:ping).and_raise(Bosh::Director::RpcTimeout)

      new_agent = mock("agent")

      @cloud.should_receive(:delete_vm).with("vm-cid").ordered
      @cloud.should_receive(:create_vm).
        with("agent-222", "sc-302", { "foo" => "bar"}, ["A", "B", "C"], [], { "key1" => "value1" }).
        ordered.and_return("new-vm-cid")

      Bosh::Director::AgentClient.stub!(:new).with("agent-222", anything).and_return(new_agent)

      new_agent.should_receive(:wait_until_ready).ordered
      new_agent.should_receive(:apply).with(spec).ordered
      new_agent.should_receive(:start).ordered

      handler.apply_resolution(:recreate_vm)

      @instance.reload
      @instance.vm.apply_spec.should == spec
      @instance.vm.cid.should == "new-vm-cid"
      @instance.vm.agent_id.should == "agent-222"
    end
  end

  describe "delete_vm_reference resolution" do
    it "skips delete_vm_reference if CID is present" do
      @agent.should_receive(:ping).and_raise(Bosh::Director::RpcTimeout)
      lambda {
        handler.apply_resolution(:delete_vm_reference)
      }.should raise_error(Bosh::Director::ProblemHandlerError,
                           /has a cloud id/)
    end

    it "skips deleting VM ref if agent is now alive" do
      @vm.update(:cid => nil)
      @agent.should_receive(:ping).and_return(:pong)

      lambda {
        handler.apply_resolution(:delete_vm_reference)
      }.should raise_error(Bosh::Director::ProblemHandlerError,
                           "Agent is responding now, skipping resolution")
    end

    it "deletes VM reference" do
      @vm.update(:cid => nil)
      @agent.should_receive(:ping).and_raise(Bosh::Director::RpcTimeout)
      handler.apply_resolution(:delete_vm_reference)
      BD::Models::Vm[@vm.id].should be_nil
    end
  end
end
