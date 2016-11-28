module Bosh::Director
  module Api
    module Extensions
      module Scoping
        module Helpers
          def current_user
            @user.username_or_client if @user
          end

          def token_scopes
            @user.scopes if @user
          end
        end

        def self.registered(app)
          app.set default_scope: :admin
          app.helpers(Helpers)
        end

        def scope(allowed_scope)
          if allowed_scope == :authorization
            # handled by the :authorization option of the route
            return
          end

          condition do
            if allowed_scope == :default
              scope = settings.default_scope
            elsif allowed_scope.kind_of?(ParamsScope)
              scope = allowed_scope.scope(params, settings.default_scope)
            else
              scope = allowed_scope
            end

            if requires_authentication?
              if @user.nil?
                # this should already be happening in base_controller#authentication
                throw(:halt, [401, "Not authorized: '#{request.path}'\n"])
              end

              @permission_authorizer.granted_or_raise(:director, scope, @user.scopes)
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
