require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class DisksController < BaseController
      get '/' do
        content_type(:json)
        orphan_json = @disk_manager.list_orphan_disks
        json_encode(orphan_json)
      end

      delete '/:orphan_disk_cid' do
        job_queue = JobQueue.new
        task = Bosh::Director::Jobs::DeleteOrphanDisks.enqueue(current_user, [params[:orphan_disk_cid]], job_queue)

        redirect "/tasks/#{task.id}"
      end
    end
  end
end
