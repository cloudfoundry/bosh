require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class ResourcesController < BaseController
      get '/resources/:id' do
        tmp_file = @resource_manager.get_resource_path(params[:id])
        send_disposable_file(tmp_file, :type => 'application/x-gzip')
      end
    end
  end
end
