require 'cli/core_ext'
require 'cli/errors'

module Bosh
  module Cli
    class BasicLoginStrategy
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
          err("Please provide username and password")
        end

        if @director.login(username, password)
          @terminal.say_green("Logged in as `#{username}'")
          @config.set_credentials(target, {
              "username" => username,
              "password" => password
            })
          @config.save
        else
          if @interactive
            @terminal.say_red("Cannot log in as `#{username}', please try again")
            login(target, username, '')
          else
            err("Cannot log in as `#{username}'")
          end
        end
      end
    end
  end
end
