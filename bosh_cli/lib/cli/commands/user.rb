# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class User < Base

    # bosh create user
    usage "create user"
    desc  "Create user"
    def create(username = nil, password = nil)
      auth_required

      if interactive?
        username = ask("Enter new username: ") if username.blank?
        if password.blank?
          password = ask("Enter new password: ") { |q| q.echo = "*" }
          password_confirmation = ask("Verify new password: ") { |q| q.echo = "*" }

          err("Passwords do not match") if password != password_confirmation
        end
      end

      if username.blank? || password.blank?
        err("Please enter username and password")
      end

      if director.create_user(username, password)
        say("User `#{username}' has been created".green)
      else
        err("Error creating user")
      end
    end

  end
end
