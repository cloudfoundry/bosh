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

ENV["TMPDIR"] = bosh_tmp_dir

Rspec.configure do |rspec_config|
  rspec_config.before(:each) do
    FileUtils.mkdir_p(bosh_dir)
  end

  rspec_config.after(:each) do
    FileUtils.rm_rf(bosh_dir)
  end

  rspec_config.after(:all) do
    FileUtils.rm_rf(bosh_tmp_dir)
  end
end

def setup_tmp_base_dir
  Bosh::Agent::Config.base_dir = File.dirname(__FILE__) + "/tmp/#{Time.now.to_i}"
  FileUtils.mkdir_p Bosh::Agent::Config.base_dir + '/bosh'
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

