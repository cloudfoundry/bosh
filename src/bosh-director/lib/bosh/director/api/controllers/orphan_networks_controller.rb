require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class OrphanNetworksController < BaseController
      def initialize(config)
        super(config)
        @orphan_networks_manager = OrphanNetworkManager.new(@logger)
      end

      get '/' do
        content_type(:json)
        orphan_json = @orphan_networks_manager.list_orphan_networks
        json_encode(orphan_json)
      end

      delete '/:name' do
        job_queue = JobQueue.new
        task = Bosh::Director::Jobs::DeleteOrphanNetworks.enqueue(current_user, [params[:name]], job_queue)

        redirect "/tasks/#{task.id}"
      end
    end
  end
end
