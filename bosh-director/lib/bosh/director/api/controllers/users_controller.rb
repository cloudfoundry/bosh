require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class UsersController < BaseController
      def initialize(config)
        super(config)
        @identity_provider = config.identity_provider
      end

      post '/', :consumes => [:json] do
        validate_user_management_support

        user = @identity_provider.get_user_from_request(request)
        @identity_provider.create_user(user)
        status(204)
        nil
      end

      put '/:username', :consumes => [:json] do
        validate_user_management_support

        user = @identity_provider.get_user_from_request(request)
        if user.username != params[:username]
          raise UserImmutableUsername, 'The username is immutable'
        end
        @identity_provider.update_user(user)
        status(204)
        nil
      end

      delete '/:username' do
        validate_user_management_support

        @identity_provider.delete_user(params[:username])
        status(204)
        nil
      end

      def validate_user_management_support
        unless @identity_provider.supports_api_update?
          raise UserManagementNotSupported, 'User management is not supported via API'
        end
      end
    end
  end
end
