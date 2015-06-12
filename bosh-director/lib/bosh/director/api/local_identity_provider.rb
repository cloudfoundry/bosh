module Bosh
  module Director
    module Api
      class LocalIdentityProvider
        def initialize(*_)
          @user_manager = Bosh::Director::Api::UserManager.new
        end

        def client_info
          {'type' => 'basic', 'options' => {}}
        end

        def corroborate_user(request_env, _)
          auth ||= Rack::Auth::Basic::Request.new(request_env)
          raise AuthenticationError unless auth.provided? && auth.basic? && auth.credentials

          if @user_manager.authenticate(*auth.credentials)
            auth.credentials.first
          else
            raise AuthenticationError
          end
        end
      end
    end
  end
end
