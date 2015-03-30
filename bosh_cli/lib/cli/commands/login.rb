require 'cli/basic_login_strategy'
require 'cli/uaa_login_strategy'
require 'cli/client/uaa'
require 'cli/client/uaa/options'
require 'cli/terminal'

module Bosh::Cli::Command
  class Login < Base
    # bosh login
    usage 'login'
    desc  'Log in to currently targeted director. ' +
        'The username and password can also be ' +
        'set in the BOSH_USER and BOSH_PASSWORD ' +
        'environment variables.'
    option '--ca-cert FILE', String, 'Path to client certificate provided to UAA server'
    def login(username = nil, password = nil)
      target_required

      login_strategy(director_info).login(target, username.to_s, password.to_s)
    end

    # bosh logout
    usage 'logout'
    desc 'Forget saved credentials for targeted director'
    def logout
      target_required
      config.set_credentials(target, nil)
      config.save
      say("You are no longer logged in to `#{target}'".make_yellow)
    end

    private

    def director_info
      director.get_status
    rescue Bosh::Cli::AuthError
      {}
    end

    def login_strategy(director_info)
      terminal = Bosh::Cli::Terminal.new(HighLine.new, BoshExtensions)
      auth_info = director_info.fetch('user_authentication', {})

      if auth_info['type'] == 'uaa'
        client_options = Bosh::Cli::Client::Uaa::Options.parse(options, auth_info['options'], ENV)
        uaa = Bosh::Cli::Client::Uaa::Client.new(client_options)
        Bosh::Cli::UaaLoginStrategy.new(terminal, uaa, config, interactive?)
      else
        Bosh::Cli::BasicLoginStrategy.new(terminal, director, config, interactive?)
      end

      rescue Bosh::Cli::Client::Uaa::Options::ValidationError => e
        err("Failed to connect to UAA: #{e.message}")
    end
  end
end
