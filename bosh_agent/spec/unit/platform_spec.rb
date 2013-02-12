require 'spec_helper'
require 'bosh_agent/platform'

describe Bosh::Agent::Platform do

  it "Loads the correct platform" do
    Bosh::Agent::Platform.new("dummy")
    require('bosh_agent/platform/dummy').should be_false
  end

  it "raises exception in case platform is not found" do
    lambda {Bosh::Agent::Platform.new("unknown")}.should raise_exception(Bosh::Agent::UnknownPlatform)
  end

  it "returns the correct class" do
    Bosh::Agent::Platform.new("dummy").platform.should be_a_kind_of Bosh::Agent::Platform::Dummy
  end

  #it 'should update logrotate from platform' do
  #  default_max_log_file_size = Bosh::Agent::Platform::Ubuntu::Logrotate::DEFAULT_MAX_LOG_FILE_SIZE
  #  spec_properties = {}
  #
  #  Bosh::Agent::Config.platform.update_logging(spec_properties)
  #
  #  match_expression = %r|size=#{default_max_log_file_size}|
  #  File.read(@logrotate_dst_path).should match(match_expression)
  #end

end