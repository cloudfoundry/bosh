# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Bosh::Agent::Platform::Ubuntu::Logrotate do

  before(:each) do
    @platform = Bosh::Agent::Platform.new("ubuntu").platform
    system_root = Bosh::Agent::Config.system_root
    @logrotate_path = File.join(system_root, 'etc', 'logrotate.d')
    FileUtils.mkdir_p(@logrotate_path)
  end

  it 'should create logrotate file named after BOSH_APP_GROUP' do
    spec_properties = {}
    Bosh::Agent::Platform::Ubuntu::Logrotate.new.install(spec_properties)
    File.exist?(File.join(@logrotate_path, Bosh::Agent::BOSH_APP_GROUP)).should == true
  end

  it 'should default to DEFAULT_MAX_LOG_FILE_SIZE' do
    default_max_log_file_size = Bosh::Agent::Platform::Ubuntu::Logrotate::DEFAULT_MAX_LOG_FILE_SIZE
    spec_properties = {}
    Bosh::Agent::Platform::Ubuntu::Logrotate.new.install(spec_properties)
    match_expression = %r|size=#{default_max_log_file_size}|
    File.read(File.join(@logrotate_path, Bosh::Agent::BOSH_APP_GROUP)).should match(match_expression)
  end

  it 'should update logrotate from platform' do
    max_log_file_size = "#{rand(100)}M"
    spec_properties = {
      "properties" => {
        "logging" => {
          "max_log_file_size" => max_log_file_size
        }
      }
    }

    @platform.update_logging(spec_properties)
    match_expression = %r|size=#{max_log_file_size}|
    File.read(File.join(@logrotate_path, Bosh::Agent::BOSH_APP_GROUP)).should match(match_expression)
  end

end
