require File.dirname(__FILE__) + '/../../spec_helper'
require 'fileutils'

describe Bosh::Agent::Message::Drain do

  before(:each) do
    setup_tmp_base_dir
    logger = mock('logger')
    logger.stub!(:info)
    Bosh::Agent::Config.logger = logger
  end

  it "should receive drain type and an optional argument" do
    handler = Bosh::Agent::Message::Drain.new(["shutdown"])
  end

  it "should handle shutdown drain type"
  it "should handle update drain type"
  it "should return 0 if it receives an update but doesn't have a previouisly applied job"

  it "should pass job update state to drain script"
  it "should pass the name of updated packages to drain script"

  it "should set BOSH_CURRENT_STATE environment varibale"
  it "should set BOSH_APPLY_SPEC environment variable"

end
