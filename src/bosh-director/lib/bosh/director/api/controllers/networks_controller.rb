require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class NetworksController < BaseController
      get '/' do
        content_type(:json)
        orphan_json = OrphanNetworkManager.new(@logger).list_orphan_networks
        json_encode(orphan_json)
      end

      delete '/:orphan_network_name' do
        job_queue = JobQueue.new
        task = Bosh::Director::Jobs::DeleteOrphanNetworks.enqueue(current_user, [params[:orphan_network_name]], job_queue)
        redirect "/tasks/#{task.id}"
      end
    end
  end
end
