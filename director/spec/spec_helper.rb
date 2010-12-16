$:.unshift(File.expand_path("../../lib", __FILE__))

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)
require "rubygems"
require "bundler"
Bundler.setup(:default, :test)

require "rspec"

ENV["RACK_ENV"] = "test"

require "director"

require "archive/tar/minitar"
require "digest/sha1"
require "fileutils"
require "tmpdir"
require "zlib"

Bosh::Director::Config.logger = Logger.new(STDOUT)

bosh_dir = Dir.mktmpdir("boshdir")
bosh_tmp_dir = Dir.mktmpdir("bosh_tmpdir")

ENV["TMPDIR"] = bosh_tmp_dir

class Object
  include Bosh::Director::DeepCopy
end

def spec_asset(filename)
  File.read(File.dirname(__FILE__) + "/assets/#{filename}")
end

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
