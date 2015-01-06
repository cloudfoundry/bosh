# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::ProblemHandlers::UnboundInstanceVm do

  def make_handler(vm_id, data = {})
    Bosh::Director::ProblemHandlers::UnboundInstanceVm.new(vm_id, data)
  end

  before(:each) do
    @cloud = instance_double('Bosh::Cloud')
    @agent = double("agent")

    @vm = Bosh::Director::Models::Vm.make(:cid => "vm-cid")

    @handler = make_handler(@vm.id, "job" => "mysql_node", "index" => 0)

    allow(@handler).to receive(:cloud).and_return(@cloud)
    allow(@handler).to receive(:agent_client).with(@vm).and_return(@agent)
  end

  it "registers under unbound_instance_vm type" do
    handler = Bosh::Director::ProblemHandlers::Base.
      create_by_type(:unbound_instance_vm, @vm.id, {})
    expect(handler).to be_kind_of(Bosh::Director::ProblemHandlers::UnboundInstanceVm)
  end

  describe "invalid states" do
    it "is invalid when VM is gone from DB" do
      @vm.destroy
      expect {
        make_handler(@vm.id)
      }.to raise_error("VM `#{@vm.id}' is no longer in the database")
    end

    it "is invalid when VM doesn't have a cloud id" do
      @vm.update(:cid => nil)
      expect {
        make_handler(@vm.id)
      }.to raise_error("VM `#{@vm.id}' doesn't have a cloud id")
    end
  end

  it "has well-formed description" do
    expect(@handler.description).to eq("VM `vm-cid' reports itself as `mysql_node/0' but does not have a bound instance")
  end

  describe "common validations" do
    [:delete_vm, :reassociate_vm].each do |resolution|
      it "fails if VM now has no job according to agent state" do
        expect(@agent).to receive(:get_state).and_return("job" => nil)

        expect {
          @handler.apply_resolution(resolution)
        }.to raise_error(Bosh::Director::ProblemHandlerError, "VM now properly reports no job")
      end

      it "fails if VM now has no job according to agent state" do
        Bosh::Director::Models::Instance.make(:job => "mysql_node", :index => 0, :vm_id => @vm.id)

        expect {
          @handler.apply_resolution(resolution)
        }.to raise_error(Bosh::Director::ProblemHandlerError, "Instance is now bound to VM")
      end

      it "fails if VM is not responding" do
        expect(@agent).to receive(:get_state).and_raise(Bosh::Director::RpcTimeout)

        expect {
          @handler.apply_resolution(:delete_vm)
        }.to raise_error(Bosh::Director::ProblemHandlerError, "VM `vm-cid' is not responding")
      end
    end
  end

  describe "delete_vm resolution" do
    it "fails if VM has a persistent disk" do
      expect(@agent).to receive(:get_state).and_return("job" => {"name" => "mysql_node"})
      expect(@agent).to receive(:list_disk).and_return(["some-disk"])

      expect {
        @handler.apply_resolution(:delete_vm)
      }.to raise_error(Bosh::Director::ProblemHandlerError, "VM has persistent disk attached")
    end

    it "deletes VM from the cloud and DB" do
      expect(@agent).to receive(:get_state).and_return("job" => {"name" => "mysql_node"})
      expect(@agent).to receive(:list_disk).and_return([])
      expect(@cloud).to receive(:delete_vm).with("vm-cid")

      @handler.apply_resolution(:delete_vm)

      expect {
        @vm.reload
      }.to raise_error(Sequel::Error, "Record not found")
    end
  end

  describe "reassociate_vm resolution" do
    it "fails if no instances in DB match this VM" do
      expect(@agent).to receive(:get_state).and_return("job" => {"name" => "mysql_node"})

      expect {
        @handler.apply_resolution(:reassociate_vm)
      }.to raise_error(Bosh::Director::ProblemHandlerError, "No instances in DB match this VM")
    end

    it "fails if instance is referencing another VM" do
      instance = Bosh::Director::Models::Instance.
        make(:deployment_id => @vm.deployment_id, :job => "mysql_node", :index => 0)
      expect(@agent).to receive(:get_state).and_return("job" => {"name" => "mysql_node"})

      expect {
        @handler.apply_resolution(:reassociate_vm)
      }.to raise_error(Bosh::Director::ProblemHandlerError, "The corresponding instance is associated with another VM")
    end

    it "reassociates VM record with its instance record" do
      instance = Bosh::Director::Models::Instance.
        make(:deployment_id => @vm.deployment_id, :job => "mysql_node", :index => 0)
      instance.update(:vm => nil)

      expect(@agent).to receive(:get_state).and_return("job" => {"name" => "mysql_node"})
      @handler.apply_resolution(:reassociate_vm)

      instance.reload
      expect(instance.vm_id).to eq(@vm.id)
    end
  end
end
