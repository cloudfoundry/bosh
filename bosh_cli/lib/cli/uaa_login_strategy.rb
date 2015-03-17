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

      def login(target, username = nil, password = nil)
        if @interactive
          credentials = {}
          @uaa.prompts.map do |prompt|
            if prompt.password?
              credentials[prompt.field] = @terminal.ask_password("#{prompt.display_text}: ")
            else
              credentials[prompt.field] = @terminal.ask("#{prompt.display_text}: ")
            end
          end

          if results = @uaa.login(credentials)
            @terminal.say_green("Logged in as `#{results[:username]}'")
            @config.set_credentials(target, { token: results[:token] })
            @config.save
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
