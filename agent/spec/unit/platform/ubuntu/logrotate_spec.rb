require File.dirname(__FILE__) + '/../../../spec_helper'

Bosh::Agent::Config.platform_name = "ubuntu"
Bosh::Agent::Config.platform

describe Bosh::Agent::Platform::Ubuntu::Logrotate do

  before(:each) do
    system_root = Bosh::Agent::Config.system_root
    @logrotate_path = File.join(system_root, 'etc', 'logrotate.d')
    FileUtils.mkdir_p(@logrotate_path)
  end

  it 'should create logrotate file named after BOSH_APP_GROUP' do
    spec_properties = {}
    Bosh::Agent::Platform::Ubuntu::Logrotate.new(spec_properties).install
    File.exist?(File.join(@logrotate_path, Bosh::Agent::BOSH_APP_GROUP)).should == true
  end

  it 'should default to DEFAULT_MAX_LOG_FILE_SIZE' do
    default_max_log_file_size = Bosh::Agent::Platform::Ubuntu::Logrotate::DEFAULT_MAX_LOG_FILE_SIZE
    spec_properties = {}
    Bosh::Agent::Platform::Ubuntu::Logrotate.new(spec_properties).install
    match_expression = %r|size=#{default_max_log_file_size}|
    File.read(File.join(@logrotate_path, Bosh::Agent::BOSH_APP_GROUP)).should match(match_expression)
  end

  it 'should update logrotate from platform' do
    default_max_log_file_size = Bosh::Agent::Platform::Ubuntu::Logrotate::DEFAULT_MAX_LOG_FILE_SIZE
    spec_properties = {}

    Bosh::Agent::Config.platform.update_logging(spec_properties)
    match_expression = %r|size=#{default_max_log_file_size}|
    File.read(File.join(@logrotate_path, Bosh::Agent::BOSH_APP_GROUP)).should match(match_expression)
  end

end
