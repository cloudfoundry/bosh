require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class NetworksController < BaseController
      get '/' do
        content_type(:json)
        orphan_param = params['orphaned']

        if orphan_param.nil? || orphan_param == 'false'
          # in the future, this might be used for listing active managed networks
          halt 500, 'listing active networks is not implemented'
        else
          orphaned_networks = OrphanNetworkManager.new(@logger).list_orphan_networks
          json_encode(orphaned_networks)
        end
      end

      delete '/:orphaned_network_name' do
        job_queue = JobQueue.new
        task = Bosh::Director::Jobs::DeleteOrphanNetworks.enqueue(current_user, [params[:orphaned_network_name]], job_queue)
        redirect "/tasks/#{task.id}"
      end
    end
  end
end
