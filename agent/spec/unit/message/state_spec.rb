require File.dirname(__FILE__) + '/../../spec_helper'
require 'fileutils'

describe Bosh::Agent::Message::State do

  before(:each) do
    tmp_base_dir = File.dirname(__FILE__) + "/../../tmp/#{Time.now.to_i}"
    if File.directory?(tmp_base_dir)
      FileUtils.rm_rf(tmp_base_dir)
    end
    Bosh::Agent::Config.base_dir = tmp_base_dir

    FileUtils.mkdir_p Bosh::Agent::Config.base_dir + '/bosh'

    @logger = mock('logger')
    @logger.stub!(:info)

    Bosh::Agent::Config.logger = @logger
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
