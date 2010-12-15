require File.dirname(__FILE__) + '/../../spec_helper'
require 'fileutils'


describe Bosh::Agent::Message::State do

  before(:each) do
    Bosh::Agent::Config.base_dir = File.dirname(__FILE__) + "/../../tmp/#{Time.now.to_i}"
    FileUtils.mkdir_p Bosh::Agent::Config.base_dir + '/bosh'

    @logger = mock('logger')
    @logger.stub!(:info)

    Bosh::Agent::Config.logger = @logger
  end

  it 'shuold have initial empty state' do
    handler = Bosh::Agent::Message::State.new(nil)
    initial_state = {
      "deployment"=>"",
      "job"=>"",
      "index"=>"",
      "networks"=>{},
      "resource_pool"=>{},
      "packages"=>{},
      "persistent_disk"=>{},
      "configuration_hash"=>{},
      "properties"=>{}
    }
    handler.state.should == initial_state
  end
end
