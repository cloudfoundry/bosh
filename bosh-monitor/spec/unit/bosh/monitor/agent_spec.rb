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
    expect(agent.timed_out?).to be(false)

    allow(Time).to receive(:now).and_return(now + 344)
    expect(agent.timed_out?).to be(false)

    allow(Time).to receive(:now).and_return(now + 345)
    expect(agent.timed_out?).to be(true)
  end

  it "knows if it is rogue if it isn't associated with deployment for :rogue_agent_alert seconds" do
    now = Time.now
    agent = make_agent("007")
    expect(agent.rogue?).to be(false)

    allow(Time).to receive(:now).and_return(now + 124)
    expect(agent.rogue?).to be(false)

    allow(Time).to receive(:now).and_return(now + 125)
    expect(agent.rogue?).to be(true)

    agent.deployment = "mycloud"
    expect(agent.rogue?).to be(false)
  end

  it "has name that depends on the currently known state" do
    agent = make_agent("zb")
    agent.cid = "deadbeef"
    expect(agent.name).to eq("agent zb [cid=deadbeef]")
    agent.deployment = "oleg-cloud"
    expect(agent.name).to eq("agent zb [deployment=oleg-cloud, cid=deadbeef]")
    agent.job = "mysql_node"
    expect(agent.name).to eq("agent zb [deployment=oleg-cloud, job=mysql_node, cid=deadbeef]")
    agent.index = "0"
    expect(agent.name).to eq("oleg-cloud: mysql_node(0) [id=zb, cid=deadbeef]")
  end

end
