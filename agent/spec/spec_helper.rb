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

def dummy_package_data
  dummy_package_data = File.open(File.dirname(__FILE__) + '/fixtures/dummy.package').read
end
