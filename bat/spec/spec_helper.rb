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

RSpec.configure do |config|
  config.include(BoshHelper)
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
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

RSpec::Matchers.define :fail_with do |expected|
  match do |actual|
    if actual.exit_status == 0
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
