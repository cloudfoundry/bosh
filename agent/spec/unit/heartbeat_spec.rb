require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Agent::Heartbeat do

  before(:each) do
    @heartbeat          = Bosh::Agent::Heartbeat.new
    @heartbeat.logger   = Logger.new(StringIO.new)
    @heartbeat.agent_id = "agent-zb"
  end

  it "publishes hearbeat via nats (using state message handler)" do
    nats = mock()
    state_handler = mock(:state => "state_payload")

    Bosh::Agent::Message::State.should_receive(:new).and_return(state_handler)
    nats.should_receive(:publish).with("hm.agent.heartbeat.agent-zb", "state_payload")

    @heartbeat.nats = nats
    @heartbeat.send_via_mbus
  end

end
