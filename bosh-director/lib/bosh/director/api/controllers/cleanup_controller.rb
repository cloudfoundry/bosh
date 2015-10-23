require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class CleanupController < BaseController
      post '/' do
        orphan_disks_json = @disk_manager.list_orphan_disks
        orphan_disk_cids = orphan_disks_json.map{ |orphan_disk_json| orphan_disk_json['disk_cid'] }

        job_queue = JobQueue.new
        task = Bosh::Director::Jobs::DeleteOrphanDisks.enqueue(current_user, orphan_disk_cids, job_queue)

        redirect "/tasks/#{task.id}"
      end
    end
  end
end
