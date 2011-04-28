require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Agent::Heartbeat do

  before(:each) do
    state_file = Tempfile.new("state")
    state_file.write(YAML.dump({ "job" => "mutator", "configuration_hash" => "deadbeef" }))
    state_file.close

    @state = Bosh::Agent::State.new(state_file.path)
    @nats = mock()

    @heartbeat          = Bosh::Agent::Heartbeat.new
    @heartbeat.logger   = Logger.new(StringIO.new)
    @heartbeat.agent_id = "agent-zb"
    @heartbeat.state    = @state
    @heartbeat.nats     = @nats
  end

  it "publishes heartbeat via nats (with job state in payload)" do
    @nats.should_receive(:publish).with("hm.agent.heartbeat.agent-zb", Yajl::Encoder.encode({ "job_state" => "running" }))
    @heartbeat.send_via_mbus
  end

  it "doesn't send heartbeats when there is no job" do
    @state.write({ "job" => nil, "configuration_hash" => "deadbeef" })
    @nats.should_not_receive(:publish)
    @heartbeat.send_via_mbus
  end

  it "doesn't send heartbeats when there is no state" do
    @heartbeat.state = nil
    @nats.should_not_receive(:publish)
    @heartbeat.send_via_mbus
  end

  it "raises an error when nats is not initialized" do
    @heartbeat.nats = nil
    lambda {
      @heartbeat.send_via_mbus
    }.should raise_error(Bosh::Agent::HeartbeatError, "NATS should be initialized in order to send heartbeats")
  end

end
