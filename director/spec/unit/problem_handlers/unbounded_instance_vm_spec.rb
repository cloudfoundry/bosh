require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::ProblemHandlers::UnboundedInstanceVm do
  before(:each) do
    @cloud = mock("cloud")
    @agent = mock("agent")
    @vm = Bosh::Director::Models::Vm.make(:cid => "vm-cid", :agent_id => "agent-1")
    Bosh::Director::AgentClient.stub!(:new).and_return(@agent)
    @handler = Bosh::Director::ProblemHandlers::Base.create_by_type(:unbounded_instance_vm, @vm.id, {})
    @handler.stub(:cloud).and_return(@cloud)
  end

  it "should skip bounded vm" do
    @agent.should_receive(:get_state).and_return({"job" => "test"})
    Bosh::Director::Models::Instance.make(:vm => @vm)
    @handler.problem_still_exists?.should be_false
  end

  it "should skip resource pool vm" do
    @agent.should_receive(:get_state).and_return({})
    @handler.problem_still_exists?.should be_false
  end

  it "should detect unbonded instance vm" do
    @agent.should_receive(:get_state).and_return({"job" => "test"})
    @handler.problem_still_exists?.should be_true
  end


  it "should delete unbounded intance vm" do
    @agent.should_receive(:list_disk).and_return([])
    @cloud.should_receive(:delete_vm).with("vm-cid")
    @handler.delete_vm
    Bosh::Director::Models::Vm[@vm.id].should be_nil
  end

  it "should refuse to delete vms with persistent disks" do
    @agent.should_receive(:list_disk).exactly(2).times.and_return(["disk-cid"])
    @cloud.should_not_receive(:delete_vm)
    lambda {@handler.delete_vm}.should raise_error Bosh::Director::ProblemHandlers::HandlerError
    Bosh::Director::Models::Vm[@vm.id].should_not be_nil
  end
end
