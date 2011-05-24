require 'spec_helper'

describe Bhm::Agent do

  before :each do
    Bhm.intervals = OpenStruct.new(:agent_timeout => 344)
  end

  def make_agent(id)
    Bhm::Agent.new(id)
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

end
