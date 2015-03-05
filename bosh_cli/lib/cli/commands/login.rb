require 'cli/basic_login_service'
require 'cli/uaa_login_service'
require 'cli/client/uaa'
require 'cli/terminal'

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

      login_service(director_info).login(target, username.to_s, password.to_s)
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

    def director_info
      director.get_status
    rescue Bosh::Cli::AuthError
      {}
    end

    def login_service(director_info)
      terminal = Bosh::Cli::Terminal.new(HighLine.new, BoshExtensions)
      auth_info = director_info.fetch('user_authentication', {})

      if auth_info['type'] == 'uaa'
        uaa = Bosh::Cli::Client::Uaa.new(auth_info['options'])
        Bosh::Cli::UaaLoginService.new(terminal, uaa, config, interactive?)
      else
        Bosh::Cli::BasicLoginService.new(terminal, director, config, interactive?)
      end
    end
  end
end
