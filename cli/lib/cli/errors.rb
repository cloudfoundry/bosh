module Bosh
  module Cli

    class CliError < StandardError; end
    class UnknownCommand < CliError; end
    
  end
end
