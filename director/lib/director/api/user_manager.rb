# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    class UserManager

      def authenticate(username, password)
        user = Models::User[:username => username]
        authenticated = user && BCrypt::Password.new(user.password) == password
        if !authenticated && Models::User.count == 0
          authenticated = %W(admin admin) == [username, password]
        end
        authenticated
      end

      def delete_user(username)
        user = Models::User[:username => username]
        raise UserNotFound.new(username) if user.nil?
        user.destroy
      end

      def create_user(new_user)
        user = Models::User.new
        user.username = new_user.username
        if new_user.password
          user.password = BCrypt::Password.create(new_user.password).to_s
        end
        user.save
        user
      rescue Sequel::ValidationFailed => e
        username_errors = e.errors.on(:username)
        if username_errors && username_errors.include?(:unique)
          raise UserNameTaken.new(user.username)
        end
        raise UserInvalid.new(e.errors.full_messages)
      end

      def update_user(updated_user)
        user = Models::User[:username => updated_user.username]
        raise UserNotFound.new(updated_user.username) if user.nil?
        user.password = BCrypt::Password.create(updated_user.password).to_s
        user.save
        user
      rescue Sequel::ValidationFailed => e
        raise UserInvalid.new(e.errors.full_messages)
      end

      def get_user_from_request(request)
        hash = Yajl::Parser.new.parse(request.body)
        Models::User.new(:username => hash["username"],
                         :password => hash["password"])
      end
    end
  end
end