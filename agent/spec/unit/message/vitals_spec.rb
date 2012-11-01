# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../../spec_helper'
require 'fileutils'

describe Bosh::Agent::Message::Vitals do

  before(:each) do
    state_file = Tempfile.new("agent-state")

    Bosh::Agent::Config.state    = Bosh::Agent::State.new(state_file.path)
    Bosh::Agent::Config.settings = { "vm" => "zb", "agent_id" => "007" }

    Bosh::Agent::Monit.enabled = true
    @monit_mock = mock('monit_api_client')
    Bosh::Agent::Monit.stub!(:monit_api_client).and_return(@monit_mock)
  end

  it "should report vitals" do
    handler = Bosh::Agent::Message::Vitals.new

    status = { "foo" => { :status => { :message => "running" }, :monitor => :yes }}
    @monit_mock.should_receive(:status).and_return(status)

    vitals = { "foo" => { :raw => { "system" => {
        "load" => {"avg01" => "1", "avg05" => "5", "avg15" => "15"},
        "cpu" => {"user" => "u", "system" => "s", "wait" => "w"},
        "memory" => {"percent" => "p", "kilobyte" => "k"},
        "swap" => {"percent" => "p", "kilobyte" => "k"},
    }}}}
    @monit_mock.should_receive(:status).and_return(vitals)

    agent_vitals = handler.vitals['vitals']
    agent_vitals['load'].should == ["1", "5", "15"] &&
    agent_vitals['cpu']['user'].should == "u" &&
    agent_vitals['mem']['percent'].should == "p" &&
    agent_vitals['swap']['percent'].should == "p"
  end

end