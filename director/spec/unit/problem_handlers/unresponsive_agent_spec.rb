# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

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

    @vm = Bosh::Director::Models::Vm.make(cid: "vm-cid", agent_id: "agent-007")
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
      @vm.update(cid: nil)
      @agent.should_receive(:ping).and_raise(Bosh::Director::RpcTimeout)

      expect {
        handler.apply_resolution(:recreate_vm)
      }.to raise_error(Bosh::Director::ProblemHandlerError, /doesn't have a cloud id/)
    end

    it "doesn't recreate VM if agent is now alive" do
      @agent.stub(ping: :pong)

      expect {
        handler.apply_resolution(:recreate_vm)
      }.to raise_error(Bosh::Director::ProblemHandlerError, "Agent is responding now, skipping resolution")
    end

    context "when no errors" do
      let(:spec) do
        {
            "resource_pool" => {
                "stemcell" => {
                    "name" => "bosh-stemcell",
                    "version" => "3.0.2"
                },
                "cloud_properties" => {"foo" => "bar"},
            },
            "networks" => ["A", "B", "C"]
        }
      end
      let(:fake_new_agent) { double(Bosh::Director::AgentClient) }

      before do
        Bosh::Director::Models::Stemcell.make(:name => "bosh-stemcell", :version => "3.0.2", :cid => "sc-302")
        @vm.update(:apply_spec => spec, :env => {"key1" => "value1"})
        Bosh::Director::AgentClient.stub(:new).with("agent-222", anything).and_return(fake_new_agent)
        SecureRandom.stub(uuid: "agent-222")
      end


      it "recreates the VM" do
        @agent.stub(:ping).and_raise(Bosh::Director::RpcTimeout)

        @cloud.should_receive(:delete_vm).with("vm-cid")
        @cloud.
            should_receive(:create_vm).
            with("agent-222", "sc-302", {"foo" => "bar"}, ["A", "B", "C"], [], {"key1" => "value1"})

        fake_new_agent.should_receive(:wait_until_ready).ordered
        fake_new_agent.should_receive(:apply).with(spec).ordered
        fake_new_agent.should_receive(:start).ordered

        Bosh::Director::Models::Vm.find(agent_id: "agent-007").should_not be_nil

        handler.apply_resolution(:recreate_vm)

        Bosh::Director::Models::Vm.find(agent_id: "agent-007").should be_nil
      end
    end
  end

  describe "delete_vm_reference resolution" do
    it "skips delete_vm_reference if CID is present" do
      @agent.should_receive(:ping).and_raise(Bosh::Director::RpcTimeout)
      expect {
        handler.apply_resolution(:delete_vm_reference)
      }.to raise_error(Bosh::Director::ProblemHandlerError, /has a cloud id/)
    end

    it "skips deleting VM ref if agent is now alive" do
      @vm.update(:cid => nil)
      @agent.should_receive(:ping).and_return(:pong)

      expect {
        handler.apply_resolution(:delete_vm_reference)
      }.to raise_error(Bosh::Director::ProblemHandlerError, "Agent is responding now, skipping resolution")
    end

    it "deletes VM reference" do
      @vm.update(:cid => nil)
      @agent.should_receive(:ping).and_raise(Bosh::Director::RpcTimeout)
      handler.apply_resolution(:delete_vm_reference)
      BD::Models::Vm[@vm.id].should be_nil
    end
  end
end
