# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    class DatabaseUserManager
      def supports_api_update?
        true
      end

      def authenticate(username, password)
        # This is a dev-mode shortcut
        if Models::User.count == 0
          return username == "admin" && password == "admin"
        end

        user = find_by_name(username)
        BCrypt::Password.new(user.password) == password
      rescue UserNotFound
        false
      end

      def delete_user(username)
        find_by_name(username).destroy
      end

      def create_user(new_user)
        user = Models::User.new
        user.username = new_user.username
        if new_user.password
          user.password = BCrypt::Password.create(new_user.password).to_s
        end
        save_user(user)
        user
      end

      def update_user(updated_user)
        user = find_by_name(updated_user.username)
        user.password = BCrypt::Password.create(updated_user.password).to_s
        save_user(user)
        user
      end

      def get_user_from_request(request)
        hash = Yajl::Parser.new.parse(request.body)
        Models::User.new(:username => hash["username"],
          :password => hash["password"])
      end

      private

      # @param [String] name User name
      # @return [Models::User] User
      def find_by_name(name)
        user = Models::User[:username => name]
        if user.nil?
          raise UserNotFound, "User `#{name}' doesn't exist"
        end
        user
      end

      # Saves user in DB and handles validation errors.
      # @param [Models::User]
      # @return [void]
      def save_user(user)
        user.save
      rescue Sequel::ValidationFailed => e
        username_errors = e.errors.on(:username)
        if username_errors && username_errors.include?(:unique)
          raise UserNameTaken, "The username #{user.username} is already taken"
        end
        raise UserInvalid, "The user is invalid: #{e.errors.full_messages}"
      end
    end
  end
end
