module Bosh
  module Director
    module Api
      class LocalIdentityProvider
        def initialize(user_manager)
          @user_manager = user_manager
        end

        def corroborate_user(request_env)
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
