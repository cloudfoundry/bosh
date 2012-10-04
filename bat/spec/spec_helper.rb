# Copyright (c) 2012 VMware, Inc.

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)

require "rubygems"
require "bundler"
Bundler.setup(:default, :test)

require "rspec"
require "httpclient"
require "json"
require "tempfile"
require "erb"
require "net/ssh"

require "common/exec"
require "common/properties"

helpers = Dir.glob("spec/helpers/*_helper.rb")
helpers.each do |helper|
  require File.expand_path(helper)
end

RSpec.configure do |config|
  config.include(BoshHelper)
  config.include(TaskHelper)
  config.include(TarHelper)
  config.include(DeploymentHelper)
  config.include(SshHelper)

  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
end
