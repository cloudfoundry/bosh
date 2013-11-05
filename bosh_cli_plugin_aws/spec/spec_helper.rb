require "cli"
require "bosh/cli/commands/aws"
require "bosh_cli_plugin_aws"
require 'webmock/rspec'

Dir[File.expand_path("./support/*", File.dirname(__FILE__))].each do |support_file|
  require support_file
end

def asset(filename)
  File.join(File.dirname(__FILE__), 'assets', filename)
end

def encoded_credentials(username, password)
  Base64.encode64("#{username}:#{password}").strip
end

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  config.order = 'random'
end
