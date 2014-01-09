# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::ProblemHandlers::OutOfSyncVm do

  def make_handler(vm, cloud, agent, data = {})
    handler = Bosh::Director::ProblemHandlers::OutOfSyncVm.new(vm.id, data)
    handler.stub(:cloud).and_return(cloud)
    Bosh::Director::AgentClient.stub(:with_defaults).with(vm.agent_id, anything).and_return(agent)
    handler
  end

  before(:each) do
    @cloud = instance_double('Bosh::Cloud')
    @agent = double("agent")

    @deployment = Bosh::Director::Models::Deployment.make(:name => "mycloud")
    @vm = Bosh::Director::Models::Vm.make(:cid => "vm-cid", :deployment => @deployment)
    @instance = Bosh::Director::Models::Instance.make(:vm => @vm, :job => "mysql_node",
                                                      :index => 2, :deployment => @deployment)
    @handler = make_handler(@vm, @cloud, @agent, "job" => "mysql_node", "index" => 0, "deployment" => "mycloud")
  end

  it "registers under out_of_sync_vm type" do
    handler = Bosh::Director::ProblemHandlers::Base.
      create_by_type(:out_of_sync_vm, @vm.id, {})
    handler.should be_kind_of(Bosh::Director::ProblemHandlers::OutOfSyncVm)
  end

  describe "invalid states" do
    it "is invalid when VM is gone from DB" do
      @instance.update(:vm => nil)
      @vm.destroy
      lambda {
        make_handler(@vm, @cloud, @agent)
      }.should raise_error("VM `#{@vm.id}' is no longer in the database")
    end
  end

  it "has well-formed description" do
    @handler.description.should == "VM `vm-cid' is out of sync: expected `mycloud: mysql_node/2', got `mycloud: mysql_node/0'"
  end

  describe "delete_vm resolution" do
    it "fails if VM is no longer referenced by an instance" do
      @instance.update(:vm => nil)

      handler = make_handler(@vm, @cloud, @agent)
      @agent.should_receive(:get_state).and_return("deployment" => "mycloud", "job" => {"name" => "mysql_node"})

      lambda {
        handler.apply_resolution(:delete_vm)
      }.should raise_error(Bosh::Director::ProblemHandlerError, "VM is now back in sync")
    end

    it "fails if VM now has proper deployment, job and index" do
      @agent.should_receive(:get_state).and_return("deployment" => "mycloud", "job" => {"name" => "mysql_node"}, "index" => 2)

      lambda {
        @handler.apply_resolution(:delete_vm)
      }.should raise_error(Bosh::Director::ProblemHandlerError, "VM is now back in sync")
    end

    it "fails if VM has a persistent disk" do
      @agent.should_receive(:get_state).and_return("job" => {"name" => "mysql_node"})
      @agent.should_receive(:list_disk).and_return(["some-disk"])

      lambda {
        @handler.apply_resolution(:delete_vm)
      }.should raise_error(Bosh::Director::ProblemHandlerError, "VM has persistent disk attached")
    end

    it "deletes VM from the cloud and DB" do
      @agent.should_receive(:get_state).and_return("job" => {"name" => "mysql_node"})
      @agent.should_receive(:list_disk).and_return([])
      @cloud.should_receive(:delete_vm).with("vm-cid")

      @handler.apply_resolution(:delete_vm)

      lambda {
        @vm.reload
      }.should raise_error(Sequel::Error, "Record not found")
    end
  end
end
