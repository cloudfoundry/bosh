require 'forwardable'

module Bosh
  module Director
    module Api
      class LocalIdentityProvider
        extend Forwardable

        def initialize(options, _)
          users = options.fetch('users', [])
          @user_manager = Bosh::Director::Api::UserManagerProvider.new.user_manager(users)
        end

        # User management is supported for backwards compatibility
        def_delegators :@user_manager, :supports_api_update?, :create_user, :update_user, :delete_user, :get_user_from_request

        def client_info
          {'type' => 'basic', 'options' => {}}
        end

        def get_user(request_env)
          auth ||= Rack::Auth::Basic::Request.new(request_env)
          raise AuthenticationError unless auth.provided? && auth.basic? && auth.credentials

          unless @user_manager.authenticate(*auth.credentials)
            raise AuthenticationError
          end

          LocalUser.new(*auth.credentials)
        end

        def valid_access?(user, _)
          @user_manager.authenticate(user.username, user.password)
        end

        def required_scopes(_)
          raise NotImplemented
        end
      end

      class LocalUser < Struct.new(:username, :password); end
    end
  end
end
