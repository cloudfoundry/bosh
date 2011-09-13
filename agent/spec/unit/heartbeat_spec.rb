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
    monit_status = {
      "service1" => {
        :monitor => :yes,
        :type => 3,
        :status => {
          :code => 10,
          :message => "running"
        },
        :raw => {
          "uptime" => 14000,
          "children" => 0,
          "memory" => {
            "percent" => 5.2,
            "percenttotal" => 5.2,
            "kilobyte" => 10200,
            "kilobytetotal" => 10200
          },
          "cpu" => {
            "percent" => 0.2,
            "percenttotal" => 0.2,
          }
        }

      },
      "service2" => {
        :monitor => :yes,
        :type => 3,
        :status => {
          :code => 12,
          :message => "running"
        },
        :raw => {
          "uptime" => 14000,
          "children" => 4,
          "memory" => {
            "percent" => 6.8,
            "percenttotal" => 9.2,
            "kilobyte" => 14800,
            "kilobytetotal" => 28800
          },
          "cpu" => {
            "percent" => 0.3,
            "percenttotal" => 2.7,
          }
        }
      }
    }

    Bosh::Agent::Monit.enabled = true
    Bosh::Agent::Monit.stub!(:get_status).and_return(monit_status)

    expected_payload = {
      "job_state" => "running",
      "vitals" => {
        "service1" => {
          "uptime" => 14000,
          "status" => "running",
          "children" => 0,
          "cpu" => 0.2,
          "cpu_total" => 0.2,
          "memory" => { "percent" => 5.2, "kb" => 10200 },
          "memory_total" => { "percent" => 5.2, "kb" => 10200 }
        },
        "service2" => {
          "uptime" => 14000,
          "status" => "running",
          "children" => 4,
          "cpu" => 0.3,
          "cpu_total" => 2.7,
          "memory" => {"percent" => 6.8, "kb" => 14800 },
          "memory_total" => { "percent" => 9.2, "kb" => 28800 }
        }
      }
    }

    @nats.should_receive(:publish) do |*args|
      args[0].should == "hm.agent.heartbeat.agent-zb"
      payload = Yajl::Parser.parse(args[1])
      payload.should == expected_payload
    end
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
