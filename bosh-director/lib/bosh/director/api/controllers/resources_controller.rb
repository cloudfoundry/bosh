require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class ResourcesController < BaseController

      def initialize(identity_provider, resource_manager)
        super(identity_provider)
        @resource_manager = resource_manager
      end

      get '/:id' do
        tmp_file = @resource_manager.get_resource_path(params[:id])
        send_disposable_file(tmp_file, :type => 'application/x-gzip')
      end
    end
  end
end
