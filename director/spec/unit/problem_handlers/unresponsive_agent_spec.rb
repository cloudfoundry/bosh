require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::ProblemHandlers::UnresponsiveAgent do

  def make_handler(vm_id, data = {})
    Bosh::Director::ProblemHandlers::UnresponsiveAgent.new(vm_id, data)
  end

  before(:each) do
    @cloud = mock("cloud")
    @agent = mock("agent")

    @vm = Bosh::Director::Models::Vm.make(:cid => "vm-cid")
    @instance = Bosh::Director::Models::Instance.make(:job => "mysql_node", :index => 0, :vm_id => @vm.id)

    @handler = make_handler(@vm.id)
    @handler.stub!(:cloud).and_return(@cloud)
    @handler.stub!(:agent_client).with(@vm).and_return(@agent)
  end

  it "registers under unresponsive_agent type" do
    handler = Bosh::Director::ProblemHandlers::Base.create_by_type(:unresponsive_agent, @vm.id, {})
    handler.should be_kind_of(Bosh::Director::ProblemHandlers::UnresponsiveAgent)
  end

  describe "invalid states" do
    it "is invalid if VM is gone" do
      @instance.destroy
      @vm.destroy
      lambda {
        make_handler(@vm.id)
      }.should raise_error("VM `#{@vm.id}' is no longer in the database")
    end

    it "is invalid if there is no cloud id" do
      @vm.update(:cid => nil)
      lambda {
        make_handler(@vm.id)
      }.should raise_error("VM `#{@vm.id}' doesn't have a cloud id")
    end
  end

  it "has well-formed description" do
    @handler.description.should == "mysql_node/0 (vm-cid) is not responding"
  end

  describe "reboot_vm resolution" do
    it "skips reboot if agent is now alive" do
      @agent.should_receive(:ping).and_return(:pong)

      lambda {
        @handler.apply_resolution(:reboot_vm)
      }.should raise_error(Bosh::Director::ProblemHandlers::HandlerError,
                           "Agent is responding now, skipping reboot")
    end

    it "reboots VM" do
      @agent.should_receive(:ping).and_raise(Bosh::Director::Client::TimeoutException)
      @cloud.should_receive(:reboot_vm).with("vm-cid")
      @agent.should_receive(:wait_until_ready)

      @handler.apply_resolution(:reboot_vm)
    end

    it "reboots VM and whines if it is still unresponsive" do
      @agent.should_receive(:ping).and_raise(Bosh::Director::Client::TimeoutException)
      @cloud.should_receive(:reboot_vm).with("vm-cid")
      @agent.should_receive(:wait_until_ready).and_raise(Bosh::Director::Client::TimeoutException)

      lambda {
        @handler.apply_resolution(:reboot_vm)
      }.should raise_error(Bosh::Director::ProblemHandlers::HandlerError,
                           "Agent still unresponsive after reboot")
    end
  end
end
