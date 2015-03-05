require 'cli/core_ext'
require 'cli/errors'

module Bosh
  module Cli
    class BasicLoginService
      def initialize(terminal, director, config, interactive)
        @terminal = terminal
        @director = director
        @config = config
        @interactive = interactive
      end

      def login(target, username, password)
        if @interactive
          username = @terminal.ask("Your username: ") if username.blank?
          password = @terminal.ask_password("Enter password: ") if password.blank?
        end

        if username.blank? || password.blank?
          raise Bosh::Cli::CliError.new("Please provide username and password")
        end

        if @director.login(username, password)
          @terminal.say_green("Logged in as `#{username}'")
          @config.set_credentials(target, username, password)
          @config.save
        else
          if @interactive
            @terminal.say_red("Cannot log in as `#{username}', please try again")
            login(target, username, '')
          else
            raise Bosh::Cli::CliError.new("Cannot log in as `#{username}'")
          end
        end
      end
    end
  end
end
