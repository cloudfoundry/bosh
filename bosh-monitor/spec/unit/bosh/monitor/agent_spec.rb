require 'spec_helper'

describe Bhm::Agent do

  before :each do
    Bhm.intervals = OpenStruct.new(:agent_timeout => 344, :rogue_agent_alert => 124)
  end

  def make_agent(id)
    Bhm::Agent.new(id)
  end

  it "knows if it is timed out" do
    now = Time.now
    agent = make_agent("007")
    agent.timed_out?.should be(false)

    Time.stub(:now).and_return(now + 344)
    agent.timed_out?.should be(false)

    Time.stub(:now).and_return(now + 345)
    agent.timed_out?.should be(true)
  end

  it "knows if it is rogue if it isn't associated with deployment for :rogue_agent_alert seconds" do
    now = Time.now
    agent = make_agent("007")
    agent.rogue?.should be(false)

    Time.stub(:now).and_return(now + 124)
    agent.rogue?.should be(false)

    Time.stub(:now).and_return(now + 125)
    agent.rogue?.should be(true)

    agent.deployment = "mycloud"
    agent.rogue?.should be(false)
  end

  it "has name that depends on the currently known state" do
    agent = make_agent("zb")
    agent.cid = "deadbeef"
    agent.name.should == "agent zb [cid=deadbeef]"
    agent.deployment = "oleg-cloud"
    agent.name.should == "agent zb [deployment=oleg-cloud, cid=deadbeef]"
    agent.job = "mysql_node"
    agent.name.should == "agent zb [deployment=oleg-cloud, job=mysql_node, cid=deadbeef]"
    agent.index = "0"
    agent.name.should == "oleg-cloud: mysql_node(0) [id=zb, cid=deadbeef]"
  end

end
