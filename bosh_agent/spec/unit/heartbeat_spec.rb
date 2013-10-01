# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

describe Bosh::Agent::Heartbeat do

  before(:each) do
    state_file = Tempfile.new("state")
    state_file.write(Psych.dump({ "job" => {"name" => "mutator" }, "index" => 3, "configuration_hash" => "deadbeef" }))
    state_file.close

    @state = Bosh::Agent::State.new(state_file.path)
    @nats = double()

    @heartbeat          = Bosh::Agent::Heartbeat.new
    @heartbeat.logger   = Logger.new(StringIO.new)
    @heartbeat.agent_id = "agent-zb"
    @heartbeat.state    = @state
    @heartbeat.nats     = @nats
  end

  it "publishes heartbeat via nats (with job state in payload)" do
    processes_status = {
      "service1" => {
        :monitor => :yes,
        :type => :process,
        :status => {
          :code => 10,
          :message => "running"
        },
      },
      "service2" => {
        :monitor => :yes,
        :type => :process,
        :status => {
          :code => 12,
          :message => "running"
        },
      }
    }

    system_status = {
      "system_deadbeef" => {
        :monitor => :yes,
        :type => :system,
        :raw => {
          "system" => {
            "load" => {
              "avg01" => 0.05,
              "avg05" => 0.1,
              "avg15" => 0.27,
            },
            "memory" => {
              "percent" => 2.7,
              "kilobyte" => 23121
            },
            "swap" => {
              "percent" => 0.0,
              "kilobyte" => 0
            },
            "cpu" => {
              "user" => 2.2,
              "system" => 0.2,
              "wait" => 3.2
            }
          }
        }
      }
    }

    client = double("monit_client")
    client.stub(:status).with(:group => "vcap").and_return(processes_status)
    client.stub(:status).with(:type => :system).and_return(system_status)

    Bosh::Agent::Monit.stub(:retry_monit_request).and_yield(client)
    Bosh::Agent::Monit.enabled = true

    fake_disk_usage = {
        :system => {:percent => '87'},
        :ephemeral => {:percent => '4'},
        :persistent => {:percent => '3'}
    }
    Bosh::Agent::DiskUtil.stub(:get_usage).and_return(fake_disk_usage)

    expected_payload = {
      "job" => "mutator",
      "index" => 3,
      "job_state" => "running",
      "vitals" => {
        "load" => [0.05, 0.1, 0.27],
        "mem" => { "percent" => 2.7, "kb" => 23121 },
        "swap" => { "percent" => 0.0, "kb" => 0 },
        "cpu" => { "user" => 2.2, "sys" => 0.2, "wait" => 3.2 },
        "disk" => {
          "system" => { "percent" => "87" },
          "ephemeral" => { "percent" => "4" },
          "persistent" => { "percent" => "3" }
        }
      },
      "ntp" => { "message" => Bosh::Agent::NTP::FILE_MISSING }
    }

    @nats.should_receive(:publish) do |*args|
      args[0].should == "hm.agent.heartbeat.agent-zb"
      payload = Yajl::Parser.parse(args[1])
      payload.should == expected_payload
    end
    @heartbeat.send_via_mbus
  end

  it "sends heartbeats when there is no job" do
    @state.write({ "job" => nil, "configuration_hash" => "deadbeef" })
    @nats.should_receive(:publish)
    @heartbeat.should_receive(:heartbeat_payload).and_return({})
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
