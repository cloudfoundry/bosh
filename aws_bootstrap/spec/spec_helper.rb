require "cli"
require "bosh/cli/commands/aws"

def asset(filename)
  File.join(File.dirname(__FILE__), 'assets', filename)
end

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  config.order = 'random'
end
