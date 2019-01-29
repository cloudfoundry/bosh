require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class RestoreController < BaseController
      post '/', :consumes => :multipart do
        @restore_manager.restore_db(params[:nginx_upload_path])

        status 202
      end
    end
  end
end
