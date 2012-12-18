# Copyright (c) 2012 VMware, Inc.

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)

require "bundler"
Bundler.setup(:default, :test)

require "rspec"

require "stemcell"
require "release"
require "deployment"
require "vm"

helpers = Dir.glob("spec/helpers/*_helper.rb")
helpers.each do |helper|
  require File.expand_path(helper)
end

RSpec.configure do |config|
  config.include(BoshHelper)
  config.include(DeploymentHelper)

  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # bosh helper isn't available, so it has to be rolled by hand
  config.before(:suite) do
    director = ENV['BAT_DIRECTOR']
    director.should_not be_nil
    output = %x{bosh target #{director} 2>&1}
    $?.exitstatus.should == 0
    output.should match /Target \w*\s*set/
  end

  config.after(:suite) do
    # any suite cleanup should go here
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