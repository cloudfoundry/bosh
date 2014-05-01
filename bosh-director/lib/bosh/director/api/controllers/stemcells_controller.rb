require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class StemcellsController < BaseController
      post '/stemcells', :consumes => :tgz do
        task = @stemcell_manager.create_stemcell(@user, request.body, :remote => false)
        redirect "/tasks/#{task.id}"
      end

      post '/stemcells', :consumes => :json do
        payload = json_decode(request.body)
        task = @stemcell_manager.create_stemcell(@user, payload['location'], :remote => true)
        redirect "/tasks/#{task.id}"
      end

      get '/stemcells' do
        stemcells = Models::Stemcell.order_by(:name.asc).map do |stemcell|
          {
            'name' => stemcell.name,
            'version' => stemcell.version,
            'cid' => stemcell.cid,
            'deployments' => stemcell.deployments.map { |d| { name: d.name } }
          }
        end
        json_encode(stemcells)
      end

      delete '/stemcells/:name/:version' do
        name, version = params[:name], params[:version]
        options = {}
        options['force'] = true if params['force'] == 'true'
        stemcell = @stemcell_manager.find_by_name_and_version(name, version)
        task = @stemcell_manager.delete_stemcell(@user, stemcell, options)
        redirect "/tasks/#{task.id}"
      end
    end
  end
end
