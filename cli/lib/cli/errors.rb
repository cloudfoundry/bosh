module Bosh
  module Cli

    class CliError < StandardError; end
    class UnknownCommand < CliError; end
    class ConfigError < CliError; end
    
  end
end
