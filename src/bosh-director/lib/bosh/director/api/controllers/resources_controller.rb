require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class ResourcesController < BaseController

      def initialize(config, resource_manager)
        super(config)
        @resource_manager = resource_manager
      end

      get '/:id' do
        @resource_manager.clean_old_tmpfiles

        tmp_file = @resource_manager.get_resource_path(params[:id])

        status 200
        headers \
          'Content-Type'  => 'application/x-gzip',
          'X-Accel-Redirect' => File.join('/x_accel_files/', tmp_file)
        body ''
      end
    end
  end
end
