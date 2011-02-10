module Bosh::Cli::Command
  class User < Base

    def create(username = nil, password = nil)
      auth_required

      unless options[:non_interactive]
        username = ask("Enter username: ") if username.blank?
        password = ask("Enter password: ") { |q| q.echo = "*" } if password.blank?
      end

      if username.blank? || password.blank?
        err "Please enter username and password"
      end

      if director.create_user(username, password)
        say "User #{username} has been created"
      else
        say "Error creating user"
      end
    end

  end
end
