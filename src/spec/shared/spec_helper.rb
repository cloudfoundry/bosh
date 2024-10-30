# This file is included by every sub-project's spec_helper
SHARED_SPEC_ROOT = File.dirname(__FILE__)
BOSH_REPO_SRC_DIR = File.expand_path(File.join(SHARED_SPEC_ROOT, '..','..'))

$LOAD_PATH << File.expand_path(SHARED_SPEC_ROOT)

if ENV['COVERAGE'] == 'true'
  require 'simplecov'

  SimpleCov.configure do
    add_filter '/spec/'
    add_filter '/vendor/'
  end

  SimpleCov.start do
    root          BOSH_REPO_SRC_DIR
    merge_timeout 3600
    # command name is injected by the spec.rake runner
    command_name ENV['BOSH_BUILD_NAME'] if ENV['BOSH_BUILD_NAME']
  end
end

require 'rspec'
require 'shared_support/deployment_manifest_helper'

# Useful to see that tests are using expected version of Ruby in CI
puts "Using #{RUBY_DESCRIPTION}"

RSpec.configure do |rspec|
  rspec.expect_with :rspec do |c|
    c.max_formatted_output_length = nil
  end

  rspec.mock_with :rspec do |c|
    c.verify_partial_doubles = true
    c.verify_doubled_constant_names = true
  end
end

# It must stay minimal!
