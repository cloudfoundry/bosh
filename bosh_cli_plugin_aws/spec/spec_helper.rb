require File.expand_path('../../../spec/shared_spec_helper', __FILE__)

require 'rspec/its'
require 'webmock/rspec'
require 'cli'
require 'bosh/cli/commands/aws'
require 'bosh_cli_plugin_aws'

Dir[File.expand_path('../support/*', __FILE__)].each { |f| require(f) }

def asset(filename)
  File.join(File.dirname(__FILE__), 'assets', filename)
end

def encoded_credentials(username, password)
  Base64.encode64("#{username}:#{password}").strip
end

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'random'
end
