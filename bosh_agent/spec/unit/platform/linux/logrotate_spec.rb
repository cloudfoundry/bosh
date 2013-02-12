# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'
require 'bosh_agent/platform/ubuntu/logrotate'

describe Bosh::Agent::Platform::Ubuntu::Logrotate do

  before(:each) do
    Bosh::Agent::Config.system_root = Dir.mktmpdir
    Bosh::Agent::Config.logger = Logger.new(STDOUT)

    @logrotate_dst_path = File.join(Bosh::Agent::Config.system_root, 'etc', 'logrotate.d', Bosh::Agent::BOSH_APP_GROUP)
    FileUtils.mkdir_p File.dirname(@logrotate_dst_path)
  end

  after(:each) do
    FileUtils.rm_rf Bosh::Agent::Config.system_root
  end

  it 'should create logrotate file named after BOSH_APP_GROUP' do
    spec_properties = {}
    Bosh::Agent::Platform::Ubuntu::Logrotate.new.install(spec_properties)
    File.exist?(@logrotate_dst_path).should == true
  end

  it 'should default to DEFAULT_MAX_LOG_FILE_SIZE if nothing is specified in the spec_properties' do
    default_max_log_file_size = Bosh::Agent::Platform::Ubuntu::Logrotate::DEFAULT_MAX_LOG_FILE_SIZE
    Bosh::Agent::Platform::Ubuntu::Logrotate.new.install({})
    match_expression = %r|size=#{default_max_log_file_size}|
    File.read(@logrotate_dst_path).should match(match_expression)
  end

  it 'should use MAX_LOG_FILE_SIZE if specified in the spec_properties' do
    max_log_file_size = '10M'
    spec_properties = {'properties' => {'logging' => {'max_log_file_size' => max_log_file_size}}}
    Bosh::Agent::Platform::Ubuntu::Logrotate.new.install(spec_properties)
    match_expression = %r|size=#{max_log_file_size}|
    File.read(@logrotate_dst_path).should match(match_expression)
  end

end
