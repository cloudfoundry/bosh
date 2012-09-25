# Copyright (c) 2012 VMware, Inc.

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)

require "rubygems"
require "bundler"
Bundler.setup(:default, :test)

require "rspec"
require "httpclient"
require "json"
require "common/common"
require "common/exec"

require "bosh_helper"
require "task_helper"
require "tar_helper"

RSpec.configure do |config|
  config.include(BoshHelper)
  config.include(TaskHelper)
  config.include(TarHelper)

  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
end
