require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class StemcellsController < BaseController
      post '/', :consumes => :json do
        payload = json_decode(request.body)
        task = @stemcell_manager.create_stemcell_from_url(current_user, payload['location'])
        redirect "/tasks/#{task.id}"
      end

      post '/', :consumes => :multipart do
        task = @stemcell_manager.create_stemcell_from_file_path(current_user, params[:nginx_upload_path])
        redirect "/tasks/#{task.id}"
      end

      get '/', scope: :read do
        stemcells = Models::Stemcell.order_by(:name.asc).map do |stemcell|
          {
            'name' => stemcell.name,
            'operating_system' => stemcell.operating_system,
            'version' => stemcell.version,
            'cid' => stemcell.cid,
            'deployments' => stemcell.deployments.map { |d| { name: d.name } }
          }
        end
        json_encode(stemcells)
      end

      delete '/:name/:version' do
        name, version = params[:name], params[:version]
        options = {}
        options['force'] = true if params['force'] == 'true'
        stemcell = @stemcell_manager.find_by_name_and_version(name, version)
        task = @stemcell_manager.delete_stemcell(current_user, stemcell, options)
        redirect "/tasks/#{task.id}"
      end
    end
  end
end
