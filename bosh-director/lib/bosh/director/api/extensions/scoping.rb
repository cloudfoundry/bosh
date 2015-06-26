module Bosh::Director
  module Api
    module Extensions
      module Scoping
        module Helpers
          def current_user
            @user.username if @user
          end
        end

        def self.registered(app)
          app.set default_scope: :write
          app.helpers(Helpers)
        end

        def scope(allowed_scope)
          condition do
            if allowed_scope == :default
              scope = settings.default_scope
            elsif allowed_scope.kind_of?(ParamsScope)
              scope = allowed_scope.scope(params, settings.default_scope)
            else
              scope = allowed_scope
            end

            auth_provided = %w(HTTP_AUTHORIZATION X-HTTP_AUTHORIZATION X_HTTP_AUTHORIZATION).detect do |key|
              request.env.has_key?(key)
            end

            if auth_provided
              begin
                @user = identity_provider.get_user(request.env)
              rescue AuthenticationError
              end
            end

            if requires_authentication? && (@user.nil? || !identity_provider.valid_access?(@user, scope))
              response['WWW-Authenticate'] = 'Basic realm="BOSH Director"'
              if @user.nil?
                message = "Not authorized: '#{request.path}'\n"
              else
                message = "Not authorized: '#{request.path}' requires one of the scopes: #{identity_provider.required_scopes(scope).join(", ")}\n"
              end
              throw(:halt, [401, message])
            end
          end
        end

        def route(verb, path, options = {}, &block)
          options[:scope] ||= :default
          super(verb, path, options, &block)
        end

        class ParamsScope
          def initialize(name, scope)
            @name = name.to_s
            @scope = scope
          end

          def scope(params, default_scope)
            scope_name = params.fetch(@name, :default).to_sym
            @scope.fetch(scope_name, default_scope)
          end
        end
      end
    end
  end
end
