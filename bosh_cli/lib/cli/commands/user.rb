# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class User < Base

    # bosh create user
    usage "create user"
    desc  "Create user"
    def create(username = nil, password = nil)
      auth_required
      show_current_state

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
        say("User `#{username}' has been created".make_green)
      else
        err("Error creating user")
      end
    end

    usage "delete user"
    desc "Deletes the user from the director"
    def delete(username = nil)
      auth_required
      show_current_state

      if interactive?
        username ||= ask("Username to delete: ")
      end

      if username.blank?
        err("Please provide a username to delete")
      end

      if confirmed?("Are you sure you would like to delete the user `#{username}'?")
        if director.delete_user(username)
          say("User `#{username}' has been deleted".make_green)
        else
          err("Unable to delete user")
        end
      end
    end
  end
end
