require File.dirname(__FILE__) + '/../../spec_helper'
require 'fileutils'

describe Bosh::Agent::Message::State do

  before(:each) do
    setup_tmp_base_dir
    logger = mock('logger')
    logger.stub!(:info)
    Bosh::Agent::Config.logger = logger
  end

  it 'shuold have initial empty state' do
    handler = Bosh::Agent::Message::State.new(nil)
    initial_state = {
      "deployment"=>"",
      "networks"=>{},
      "resource_pool"=>{}
    }

    # FIXME: initial state will _not_ be running when job handling is
    # implemented
    initial_state["job_state"] = "running"

    handler.state.should == initial_state
  end
end
