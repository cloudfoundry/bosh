require 'cli/core_ext'
require 'cli/errors'

module Bosh
  module Cli
    class UaaLoginStrategy
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
          err("Non-interactive UAA login is not supported.")
        end
      end
    end
  end
end
