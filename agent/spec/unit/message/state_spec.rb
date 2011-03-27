require File.dirname(__FILE__) + '/../../spec_helper'
require 'fileutils'

describe Bosh::Agent::Message::State do

  before(:each) do
    setup_tmp_base_dir
    logger = mock('logger')
    logger.stub!(:info)
    Bosh::Agent::Config.logger = logger
    Bosh::Agent::Config.settings = { "vm" => {}, "agent_id" => nil }

    @monit_mock = mock('monit_api_client')
    Bosh::Agent::Monit.stub!(:monit_api_client).and_return(@monit_mock)
  end

  it 'shuold have initial empty state' do
    handler = Bosh::Agent::Message::State.new(nil)
    initial_state = {
      "deployment"=>"",
      "networks"=>{},
      "resource_pool"=>{},
      "agent_id" => nil,
      "vm" => {},
      "job_state" => nil
    }
    handler.stub!(:job_state).and_return(nil)
    handler.state.should == initial_state
  end

  it "should report job_state as running" do
    handler = Bosh::Agent::Message::State.new(nil)

    status = { "foo" => { :status => { :message => "running" }, :monitor => :yes }}
    @monit_mock.should_receive(:status).and_return(status)

    handler.state['job_state'].should == "running"
  end

  it "should report job_state as starting" do
    handler = Bosh::Agent::Message::State.new(nil)

    status = { "foo" => { :status => { :message => "running" }, :monitor => :init }}
    @monit_mock.should_receive(:status).and_return(status)

    handler.state['job_state'].should == "starting"
  end

  it "should report job_state as failing" do
    handler = Bosh::Agent::Message::State.new(nil)

    status = { "foo" => { :status => { :message => "born to run" }, :monitor => :yes }}
    @monit_mock.should_receive(:status).and_return(status)

    handler.state['job_state'].should == "failing"
  end

end
