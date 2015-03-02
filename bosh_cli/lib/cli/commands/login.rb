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

      if interactive?
        username = ask("Your username: ").to_s if username.blank?

        password_retries = 0
        while password.blank? && password_retries < 3
          password = ask("Enter password: ") { |q| q.echo = "*" }.to_s
          password_retries += 1
        end
      end

      if username.blank? || password.blank?
        err("Please provide username and password")
      end
      logged_in = false

      #Converts HighLine::String to String
      username = username.to_s
      password = password.to_s

      director.user = username
      director.password = password

      if director.authenticated?
        say("Logged in as `#{username}'".make_green)
        logged_in = true
      elsif non_interactive?
        err("Cannot log in as `#{username}'".make_red)
      else
        say("Cannot log in as `#{username}', please try again".make_red)
        login(username)
      end

      if logged_in
        config.set_credentials(target, username, password)
        config.save
      end
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
