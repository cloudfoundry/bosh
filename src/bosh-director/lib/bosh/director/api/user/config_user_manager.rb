require 'digest'
require 'openssl'

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
        stored_password = user && user['password']
        stored_password_valid = stored_password.is_a?(String)
        expected_password = stored_password_valid ? stored_password : ''
        password_matches = OpenSSL.fixed_length_secure_compare(
          Digest::SHA256.digest(expected_password),
          Digest::SHA256.digest(password),
        )
        password_matches && stored_password_valid
      end

      def user_scopes(username)
        user = @users.find { |u| u['name'] == username }
        raise "User #{username} not found in ConfigUserManager" if user.nil?

        user.fetch('scopes', ['bosh.admin'])
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
