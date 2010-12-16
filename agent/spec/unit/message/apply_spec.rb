require File.dirname(__FILE__) + '/../../spec_helper'
require 'fileutils'

describe Bosh::Agent::Message::Apply do

  before(:each) do
    Bosh::Agent::Config.base_dir = File.dirname(__FILE__) + "/../../tmp/#{Time.now.to_i}"
    FileUtils.mkdir_p Bosh::Agent::Config.base_dir + '/bosh'

    logger = mock('logger')
    logger.stub!(:info)
    Bosh::Agent::Config.logger = logger
  end

  it 'should set deployment in agents state if blank' do
    state = Bosh::Agent::Message::State.new(nil)
    handler = Bosh::Agent::Message::Apply.new({"deployment" => "foo"})
    handler.apply
    state.state['deployment'].should == "foo"
  end

end

