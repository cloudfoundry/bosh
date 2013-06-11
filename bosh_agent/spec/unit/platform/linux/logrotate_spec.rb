# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

describe Bosh::Agent::Platform::Linux::Logrotate do
  let(:system_root)         { Dir.mktmpdir }
  let(:logrotate_dst_path)  { File.join(system_root, 'etc', 'logrotate.d', Bosh::Agent::BOSH_APP_GROUP) }
  let(:log_rotate)          {

    Bosh::Agent::Config.system_root = system_root
    Bosh::Agent::Config.logger = Logger.new("/dev/null")

    template_dir = Dir.mktmpdir
    File.open(File.join(template_dir, "logrotate.erb"), "w") {|f| f.write("size=<%= size %>\n base_dir=<%= base_dir %>") }

    Bosh::Agent::Platform::Linux::Logrotate.new(template_dir)
  }

  before(:each) do
    FileUtils.mkdir_p File.dirname(logrotate_dst_path)
  end

  after(:each) do
    FileUtils.rm_rf Bosh::Agent::Config.system_root
  end

  it 'should create logrotate file named after BOSH_APP_GROUP' do
    log_rotate.install({})
    File.exist?(logrotate_dst_path).should == true
  end

  it 'should default to DEFAULT_MAX_LOG_FILE_SIZE if nothing is specified in the spec_properties' do
    default_max_log_file_size = Bosh::Agent::Platform::Linux::Logrotate::DEFAULT_MAX_LOG_FILE_SIZE
    log_rotate.install({})
    match_expression = %r|size=#{default_max_log_file_size}|
    File.read(logrotate_dst_path).should match(match_expression)
  end

  it 'should use MAX_LOG_FILE_SIZE if specified in the spec_properties' do
    max_log_file_size = '10M'
    spec_properties = {'properties' => {'logging' => {'max_log_file_size' => max_log_file_size}}}
    log_rotate.install(spec_properties)
    match_expression = %r|size=#{max_log_file_size}|
    File.read(logrotate_dst_path).should match(match_expression)
  end

end
