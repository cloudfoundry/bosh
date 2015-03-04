require 'cli/terminal'
require 'cli/login_service'

module Bosh::Cli::Command
  class Login < Base
    # bosh login
    usage "login"
    desc  "Log in to currently targeted director. " +
          "The username and password can also be " +
          "set in the BOSH_USER and BOSH_PASSWORD " +
          "environment variables."
    def login(username = nil, password = nil)
      target_required

      terminal = Bosh::Cli::Terminal.new(HighLine.new)
      Bosh::Cli::LoginService.new(terminal, director, config, interactive?).login(target, username.to_s, password.to_s)
    end

    # bosh logout
    usage "logout"
    desc  "Forget saved credentials for targeted director"
    def logout
      target_required
      config.set_credentials(target, nil, nil)
      config.save
      say("You are no longer logged in to `#{target}'".make_yellow)
    end

    private

    def get_director_status
      Bosh::Cli::Client::Director.new(target).get_status
    end
  end
end
