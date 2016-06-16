require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class StemcellsController < BaseController
      post '/', :consumes => :json do
        payload = json_decode(request.body.read)
        options = {
            fix: params['fix'] == 'true',
            sha1: payload['sha1']
        }
        task = @stemcell_manager.create_stemcell_from_url(current_user, payload['location'], options)
        redirect "/tasks/#{task.id}"
      end

      post '/', :consumes => :multipart do
        options = {
            fix: params['fix'] == 'true',
            sha1: params['sha1']
        }
        task = @stemcell_manager.create_stemcell_from_file_path(current_user, params[:nginx_upload_path], options)
        redirect "/tasks/#{task.id}"
      end

      get '/', scope: :read_stemcells do
        stemcells = @stemcell_manager.find_all_stemcells
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
