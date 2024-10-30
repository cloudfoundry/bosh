# This file is included by every sub-project's spec_helper
SHARED_SPEC_ROOT = File.dirname(__FILE__)
BOSH_REPO_SRC_DIR = File.expand_path(File.join(SHARED_SPEC_ROOT, '..','..'))

$LOAD_PATH << File.expand_path(SHARED_SPEC_ROOT)

require 'rspec'
require 'shared_support/deployment_manifest_helper'

require 'shared_support/simplecov' if ENV['COVERAGE'] == 'true'

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
