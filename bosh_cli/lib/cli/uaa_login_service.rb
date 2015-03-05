require 'cli/core_ext'
require 'cli/errors'

module Bosh
  module Cli
    class UaaLoginService
      def initialize(terminal, uaa, config, interactive)
        @terminal = terminal
        @uaa = uaa
        @config = config
        @interactive = interactive
      end

      def login(target, username, password)
        if @interactive
          @uaa.prompts.map do |prompt|
            if prompt.password?
              @terminal.ask_password("#{prompt.display_text}: ")
            else
              @terminal.ask("#{prompt.display_text}: ")
            end
          end
        else
          raise Bosh::Cli::CliError.new("Non-interactive UAA login is not supported.")
        end
      end
    end
  end
end
