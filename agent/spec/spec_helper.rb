$:.unshift(File.expand_path("../../lib", __FILE__))

ENV['BUNDLE_GEMFILE'] ||= File.expand_path("../../Gemfile", __FILE__)
require 'rubygems'
require 'bundler'
Bundler.setup(:default, :test)
require 'rspec'

ENV['RACK_ENV'] = "test"

require "agent"

require "digest/sha1"
require "fileutils"
require "tmpdir"
require "zlib"

bosh_dir = Dir.mktmpdir("boshdir")
bosh_tmp_dir = Dir.mktmpdir("bosh_tmpdir")
spec_tmp_dir = File.join(File.dirname(__FILE__), "tmp")

ENV["TMPDIR"] = bosh_tmp_dir

at_exit do
  FileUtils.rm_rf(bosh_dir)
  FileUtils.rm_rf(bosh_tmp_dir)
  FileUtils.rm_rf(spec_tmp_dir)
end

Rspec.configure do |rspec_config|
  rspec_config.before(:each) do
    clear_configuration
    use_dummy_logger
    setup_directories(spec_tmp_dir)
  end

  rspec_config.after(:each) do
    FileUtils.rm_rf(bosh_dir)
    FileUtils.rm_rf(bosh_tmp_dir)
    FileUtils.rm_rf(spec_tmp_dir)
  end
end

def use_dummy_logger
  Bosh::Agent::Config.logger = Logger.new(StringIO.new)
end

def setup_directories(spec_tmp_dir)
  base_dir = File.join(spec_tmp_dir, "bosh")
  sys_root = File.join(spec_tmp_dir, "system_root")

  FileUtils.mkdir_p(base_dir)
  FileUtils.mkdir_p(sys_root)

  Bosh::Agent::Config.system_root = sys_root
  Bosh::Agent::Config.base_dir = base_dir
end

def clear_configuration
  Bosh::Agent::Config.clear
end

def base_dir
  Bosh::Agent::Config.base_dir
end

def read_asset(filename)
  File.open(File.join(File.dirname(__FILE__), 'assets', filename)).read
end

def dummy_package_data
  read_asset('dummy.package')
end

def failing_package_data
  read_asset('failing.package')
end

def dummy_job_data
  read_asset('job.tgz')
end

