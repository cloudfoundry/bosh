require 'spec_helper'

describe Bhm::Agent do

  before :each do
    Bhm.intervals = OpenStruct.new(:agent_timeout => 344, :rogue_agent_alert => 124)
  end

  def make_agent(id, deployment = nil, job = nil, index = nil)
    Bhm::Agent.new(id, deployment, job, index)
  end

  it "knows if it is timed out" do
    now = Time.now
    agent = make_agent("007")
    agent.timed_out?.should be_false

    Time.stub!(:now).and_return(now + 344)
    agent.timed_out?.should be_false

    Time.stub!(:now).and_return(now + 345)
    agent.timed_out?.should be_true
  end

  it "knows if it is rogue if it isn't associated with deployment for :rogue_agent_alert seconds" do
    now = Time.now
    agent = make_agent("007")
    agent.rogue?.should be_false

    Time.stub!(:now).and_return(now + 124)
    agent.rogue?.should be_false

    Time.stub!(:now).and_return(now + 125)
    agent.rogue?.should be_true

    agent.deployment = "mycloud"
    agent.rogue?.should be_false
  end

  it "can exist without job name and index" do
    agent = make_agent("zb")
    agent.cid = "deadbeef"
    agent.name.should == "unknown deployment: unknown job(index n/a) [agent_id=zb, cid=deadbeef]"
  end

  it "has well-formed name" do
    agent = make_agent("zb-023-ppc", "oleg-cloud", "mysql_node", "0")
    agent.name.should == "oleg-cloud: mysql_node(0) [agent_id=zb-023-ppc, cid=]"
  end

end
