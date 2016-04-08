require 'forwardable'

module Bosh
  module Director
    module Api
      class LocalIdentityProvider
        extend Forwardable

        def initialize(options)
          users = options.fetch('users', [])
          @user_manager = Bosh::Director::Api::UserManagerProvider.new.user_manager(users)
        end

        # User management is supported for backwards compatibility
        def_delegators :@user_manager, :supports_api_update?, :create_user, :update_user, :delete_user, :get_user_from_request

        def client_info
          {'type' => 'basic', 'options' => {}}
        end

        def get_user(request_env, _)
          auth ||= Rack::Auth::Basic::Request.new(request_env)
          raise AuthenticationError unless auth.provided? && auth.basic? && auth.credentials

          unless @user_manager.authenticate(*auth.credentials)
            raise AuthenticationError
          end

          LocalUser.new(*auth.credentials)
        end
      end

      class LocalUser < Struct.new(:username, :password)
        def scopes
          ['bosh.admin']
        end

        def username_or_client
          username
        end

        def client
          nil
        end
      end
    end
  end
end
