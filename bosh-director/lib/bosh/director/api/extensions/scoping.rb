module Bosh::Director
  module Api
    module Extensions
      module Scoping
        module Helpers
          def current_user
            @user
          end
        end

        def self.registered(app)
          app.set default_scope: :write
          app.helpers(Helpers)
        end

        def scope(*roles)
          condition do
            roles = [settings.default_scope] if roles == [:default]

            auth_provided = %w(HTTP_AUTHORIZATION X-HTTP_AUTHORIZATION X_HTTP_AUTHORIZATION).detect do |key|
              request.env.has_key?(key)
            end

            if auth_provided
              begin
                @user = identity_provider.corroborate_user(request.env, roles)
              rescue AuthenticationError
              end
            end

            if requires_authentication? && @user.nil?
              response['WWW-Authenticate'] = 'Basic realm="BOSH Director"'
              throw(:halt, [401, "Not authorized\n"])
            end
          end
        end

        def route(verb, path, options = {}, &block)
          options[:scope] ||= :default
          super(verb, path, options, &block)
        end
      end
    end
  end
end
