# Copyright (c) 2009-2012 VMware, Inc.

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)

require "rubygems"
require "bundler"
Bundler.setup(:default, :test)

require "rspec"
require "deployer"

def spec_asset(filename)
  File.expand_path("../assets/#{filename}", __FILE__)
end

RSpec.configure do |c|
  c.fail_fast = true if ENV['BOSH_DEPLOYER_DIR']
end
