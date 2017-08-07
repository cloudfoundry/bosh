require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class OrphanDisksController < BaseController

      def initialize(config)
        super(config)
        @orphan_disk_manager = OrphanDiskManager.new(@logger)
      end

      get '/' do
        content_type(:json)
        orphan_json = @orphan_disk_manager.list_orphan_disks
        json_encode(orphan_json)
      end

      delete '/:cid' do
        job_queue = JobQueue.new
        task = Bosh::Director::Jobs::DeleteOrphanDisks.enqueue(current_user, [params[:cid]], job_queue)

        redirect "/tasks/#{task.id}"
      end
    end
  end
end
