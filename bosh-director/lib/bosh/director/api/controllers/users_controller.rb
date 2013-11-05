require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class UsersController < BaseController
      post '/users', :consumes => [:json] do
        user = @user_manager.get_user_from_request(request)
        @user_manager.create_user(user)
        status(204)
        nil
      end

      put '/users/:username', :consumes => [:json] do
        user = @user_manager.get_user_from_request(request)
        if user.username != params[:username]
          raise UserImmutableUsername, 'The username is immutable'
        end
        @user_manager.update_user(user)
        status(204)
        nil
      end

      delete '/users/:username' do
        @user_manager.delete_user(params[:username])
        status(204)
        nil
      end
    end
  end
end
