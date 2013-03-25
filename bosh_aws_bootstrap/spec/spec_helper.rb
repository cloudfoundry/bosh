require "cli"
require "bosh/cli/commands/aws"
require "bosh_aws_bootstrap"
require 'webmock/rspec'

def asset(filename)
  File.join(File.dirname(__FILE__), 'assets', filename)
end

def mock_volume(id)
  volume = mock("volume")
  volume.stub(:id => id)
  volume.stub(:create_snapshot => nil)
  volume
end

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  config.order = 'random'
end
