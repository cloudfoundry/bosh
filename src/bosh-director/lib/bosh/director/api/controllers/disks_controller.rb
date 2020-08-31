require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class DisksController < BaseController
      get '/' do
        content_type(:json)
        orphan_json = OrphanDiskManager.new(@logger).list_orphan_disks
        json_encode(orphan_json)
      end

      get '/persistent_disks' do
        content_type(:json)
        disks_json = DiskManager.new(@logger).list_disks
        json_encode(disks_json)
      end

      # PUT /disks/disk_cid/attachments?deployment=foo&job=dea&instance_id=17f01a35-bf9c-4949-bcf2-c07a95e4df33
      put '/:disk_cid/attachments' do
        deployment = Api::DeploymentManager.new.find_by_name(params[:deployment])
        job_queue = JobQueue.new
        task = Bosh::Director::Jobs::AttachDisk.enqueue(current_user, deployment, params[:job], params[:instance_id], params[:disk_cid], params[:disk_properties] || '', job_queue)

        redirect "/tasks/#{task.id}"
      end

      delete '/:orphan_disk_cid' do
        job_queue = JobQueue.new
        orphan_param = params['orphan']
        if orphan_param.nil? || orphan_param == 'false'
          task = Bosh::Director::Jobs::DeleteOrphanDisks.enqueue(current_user, [params[:orphan_disk_cid]], job_queue)
        else
          task = Bosh::Director::Jobs::OrphanDiskJob.enqueue(current_user, params[:orphan_disk_cid], job_queue)
        end

        redirect "/tasks/#{task.id}"
      end
    end
  end
end
