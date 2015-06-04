require 'cli/core_ext'
require 'cli/errors'

module Bosh
  module Cli
    class UaaLoginStrategy
      def initialize(terminal, uaa_client, interactive)
        @terminal = terminal
        @uaa_client = uaa_client
        @interactive = interactive
      end

      def login(target, username = nil, password = nil)
        if @interactive
          credentials = {}
          @uaa_client.prompts.map do |prompt|
            if prompt.password?
              credentials[prompt.field] = @terminal.ask_password("#{prompt.display_text}: ")
            else
              credentials[prompt.field] = @terminal.ask("#{prompt.display_text}: ")
            end
          end

          if access_info = @uaa_client.access_info(credentials)
            @terminal.say_green("Logged in as `#{access_info.username}'")
          else
            err('Failed to log in')
          end
        else
          err('Non-interactive UAA login is not supported.')
        end
      end
    end
  end
end
