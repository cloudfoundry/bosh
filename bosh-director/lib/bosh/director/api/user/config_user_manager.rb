# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    class ConfigUserManager
      def initialize(users)
        @users = users
      end

      def supports_api_update?
        false
      end

      # @param [String] name User name
      def find_by_name(name)
        user = @users.find { |u| u['name'] == name }
        if user.nil?
          raise UserNotFound, "User `#{name}' doesn't exist"
        end
        User.new(user)
      end

      def authenticate(username, password)
        return false if username.empty? || password.empty?

        user = find_by_name(username)
        user.password == password
      rescue UserNotFound
        false
      end

      def delete_user(_)
        raise NotSupported
      end

      def create_user(_)
        raise NotSupported
      end

      def update_user(_)
        raise NotSupported
      end

      def get_user_from_request(_)
        raise NotSupported
      end
    end

    private

    class User
      attr_reader :username, :password

      def initialize(options)
        @username = options.fetch('name')
        @password = options.fetch('password')
      end
    end
  end
end
