module Bosh::Director
  module Api
    class ConfigUserManager
      def initialize(users)
        @users = users
      end

      def supports_api_update?
        false
      end

      def authenticate(username, password)
        return false if username.empty? || password.empty?

        user = @users.find { |u| u['name'] == username }
        return false if user.nil?

        user['password'] == password
      end

      def user_scopes(username)
        user = @users.find { |u| u['name'] == username }
        raise "User #{username} not found in ConfigUserManager" if user.nil?
        return user.fetch('scopes', ['bosh.admin'])
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

      def get_user_from_json(_)
        raise NotSupported
      end
    end
  end
end
