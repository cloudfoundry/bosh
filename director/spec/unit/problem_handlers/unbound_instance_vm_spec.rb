require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::ProblemHandlers::UnboundInstanceVm do

  def make_handler(vm_id, data = {})
    Bosh::Director::ProblemHandlers::UnboundInstanceVm.new(vm_id, data)
  end

  before(:each) do
    @cloud = mock("cloud")
    @agent = mock("agent")

    @vm = Bosh::Director::Models::Vm.make(:cid => "vm-cid")

    @handler = make_handler(@vm.id, "job" => "mysql_node", "index" => 0)

    @handler.stub!(:cloud).and_return(@cloud)
    @handler.stub!(:agent_client).with(@vm).and_return(@agent)
  end

  it "registers under unbound_instance_vm type" do
    handler = Bosh::Director::ProblemHandlers::Base.
      create_by_type(:unbound_instance_vm, @vm.id, {})
    handler.should be_kind_of(Bosh::Director::ProblemHandlers::UnboundInstanceVm)
  end

  describe "invalid states" do
    it "is invalid when VM is gone from DB" do
      @vm.destroy
      lambda {
        make_handler(@vm.id)
      }.should raise_error("VM `#{@vm.id}' is no longer in the database")
    end

    it "is invalid when VM doesn't have a cloud id" do
      @vm.update(:cid => nil)
      lambda {
        make_handler(@vm.id)
      }.should raise_error("VM `#{@vm.id}' doesn't have a cloud id")
    end
  end

  it "has well-formed description" do
    @handler.description.should == "VM `vm-cid' reports itself as `mysql_node/0' but does not have a bound instance"
  end

  describe "delete_vm resolution" do
    it "fails if VM now has no job according to agent state" do
      @agent.should_receive(:get_state).and_return("job" => nil)

      lambda {
        @handler.apply_resolution(:delete_vm)
      }.should raise_error(Bosh::Director::ProblemHandlers::HandlerError, "VM now properly reports no job")
    end

    it "fails if VM now has no job according to agent state" do
      Bosh::Director::Models::Instance.make(:job => "mysql_node", :index => 0, :vm_id => @vm.id)

      lambda {
        @handler.apply_resolution(:delete_vm)
      }.should raise_error(Bosh::Director::ProblemHandlers::HandlerError, "Instance is now bound to VM")
    end

    it "fails if VM has a persistent disk" do
      @agent.should_receive(:get_state).and_return("job" => "mysql_node")
      @agent.should_receive(:list_disk).and_return(["some-disk"])

      lambda {
        @handler.apply_resolution(:delete_vm)
      }.should raise_error(Bosh::Director::ProblemHandlers::HandlerError, "VM has persistent disk attached")
    end

    it "fails if VM is not responding" do
      @agent.should_receive(:get_state).and_raise(Bosh::Director::Client::TimeoutException)

      lambda {
        @handler.apply_resolution(:delete_vm)
      }.should raise_error(Bosh::Director::ProblemHandlers::HandlerError, "VM is not responding")
    end

    it "deletes VM from the cloud and DB" do
      @agent.should_receive(:get_state).and_return("job" => "mysql_node")
      @agent.should_receive(:list_disk).and_return([])
      @cloud.should_receive(:delete_vm).with("vm-cid")

      @handler.apply_resolution(:delete_vm)

      lambda {
        @vm.reload
      }.should raise_error(Sequel::Error, "Record not found")
    end
  end
end
