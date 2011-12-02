require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::ProblemHandlers::UnresponsiveAgent do
  before(:each) do
    @cloud = mock("cloud")
    @agent = mock("agent")
    @vm = Bosh::Director::Models::Vm.make(:cid => "vm-cid", :agent_id => "agent-1")
    Bosh::Director::AgentClient.stub!(:new).and_return(@agent)
    @handler = Bosh::Director::ProblemHandlers::Base.create_by_type(:unresponsive_agent, @vm.id, {})
    @handler.stub(:cloud).and_return(@cloud)
  end

  it "should detect unresponsive agent" do
    @agent.should_receive(:wait_until_ready).and_raise(Bosh::Director::Client::TimeoutException)
    @handler.problem_still_exists?.should be_true
  end

  it "should reboot vm with the un-responsive agent" do
    @cloud.should_receive(:reboot_vm).with("vm-cid")
    @agent.should_receive(:wait_until_ready)
    @handler.reboot_vm
  end
end
