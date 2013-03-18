# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../../spec_helper'
require 'fileutils'

describe Bosh::Agent::Message::State do

  before(:each) do
    state_file = Tempfile.new("agent-state")

    Bosh::Agent::Config.state    = Bosh::Agent::State.new(state_file.path)
    Bosh::Agent::Config.settings = { "vm" => "zb", "agent_id" => "007" }

    Bosh::Agent::Monit.enabled = true
    @monit_mock = mock('monit_api_client')
    Bosh::Agent::Monit.stub!(:monit_api_client).and_return(@monit_mock)
  end

  it 'should have initial empty state' do
    handler = Bosh::Agent::Message::State.new
    initial_state = {
      "deployment"    => "",
      "networks"      => { },
      "resource_pool" => { },
      "agent_id"      => "007",
      "vm"            => "zb",
      "job_state"     => [ ],
      "bosh_protocol" => Bosh::Agent::BOSH_PROTOCOL,
      "ntp"           => { "message" => Bosh::Agent::NTP::FILE_MISSING }
    }
    handler.stub!(:job_state).and_return([])
    handler.state.should == initial_state
  end

  it "should report job_state as running" do
    handler = Bosh::Agent::Message::State.new

    status = { "foo" => { :status => { :message => "running" }, :monitor => :yes }}
    @monit_mock.should_receive(:status).and_return(status)

    handler.state['job_state'].should == "running"
  end

  it "should report job_state as starting" do
    handler = Bosh::Agent::Message::State.new

    status = { "foo" => { :status => { :message => "running" }, :monitor => :init }}
    @monit_mock.should_receive(:status).and_return(status)

    handler.state['job_state'].should == "starting"
  end

  it "should report job_state as failing" do
    handler = Bosh::Agent::Message::State.new

    status = { "foo" => { :status => { :message => "born to run" }, :monitor => :yes }}
    @monit_mock.should_receive(:status).and_return(status)

    handler.state['job_state'].should == "failing"
  end

end
