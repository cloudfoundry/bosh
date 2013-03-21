# Copyright (c) 2012 VMware, Inc.

require "rspec"

require "yaml"
require "stemcell"
require "release"
require "deployment"
require "vm"

require 'tempfile'
require 'common/exec'
require 'resolv'

SPEC_ROOT = File.expand_path(File.dirname(__FILE__))
ASSETS_DIR = File.join(SPEC_ROOT, "assets")
BAT_RELEASE_DIR = File.join(ASSETS_DIR, "bat-release")

helper_regex = File.join(File.expand_path(File.dirname(__FILE__)),"helpers", "*_helper.rb")
helpers = Dir.glob(helper_regex)
helpers.each do |helper|
  require File.expand_path(helper)
end

BH = BoshHelper

RSpec.configure do |config|
  config.include(BoshHelper)
  config.include(DeploymentHelper)

  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # bosh helper isn't available, so it has to be rolled by hand
  config.before(:suite) do
    director = BH::read_environment('BAT_DIRECTOR')
    director.should_not be_nil
    cmd = "bundle exec bosh --config #{BH::bosh_cli_config_path} --user admin " +
      "--password admin target #{director} 2>&1"
    output = %x{#{cmd}}
    $?.exitstatus.should == 0
    output.should match /Target \w*\s*set/
  end

  config.after(:suite) do
    BH::delete_bosh_cli_config
  end

  config.before(:each) do
    requirement :no_tasks_processing unless example.metadata[:skip_task_check]
  end
end

RSpec::Matchers.define :succeed do |expected|
  match do |actual|
    actual.exit_status == 0
  end
end

RSpec::Matchers.define :succeed_with do |expected|
  match do |actual|
    if actual.exit_status != 0
      false
    elsif expected.instance_of?(String)
      actual.output == expected
    elsif expected.instance_of?(Regexp)
      !!actual.output.match(expected)
    else
      raise ArgumentError, "don't know what to do with a #{expected.class}"
    end
  end
  failure_message_for_should do |actual|
    if expected.instance_of?(Regexp)
      what = "match"
      exp = "/#{expected.source}/"
    else
      what = "be"
      exp = expected
    end
    "expected\n#{actual.output}to #{what}\n#{exp}"
  end
end
