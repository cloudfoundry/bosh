require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class DynamicDisksController < BaseController
      include ValidationHelper

      post '/provide', scope: :update_dynamic_disks, consumes: :json do
        request_hash = JSON.parse(request.body.read)

        instance_id = safe_property(request_hash, 'instance_id', class: String, min_length: 1)
        disk_name = safe_property(request_hash, 'disk_name', class: String, min_length: 1)
        disk_pool_name = safe_property(request_hash, 'disk_pool_name', class: String, min_length: 1)
        disk_size = safe_property(request_hash, 'disk_size', class: Integer, min: 1)
        metadata = safe_property(request_hash, 'metadata', class: Hash, optional: true)

        task = JobQueue.new.enqueue(
          current_user,
          Jobs::DynamicDisks::ProvideDynamicDisk,
          'provide dynamic disk',
          [instance_id, disk_name, disk_pool_name, disk_size, metadata]
        )

        redirect "/tasks/#{task.id}"
      end

      post '/:disk_name/detach', scope: :update_dynamic_disks do
        disk_name = safe_property(params, 'disk_name', class: String, min_length: 1)

        task = JobQueue.new.enqueue(
          current_user,
          Jobs::DynamicDisks::DetachDynamicDisk,
          'detach dynamic disk',
          [disk_name]
        )

        redirect "/tasks/#{task.id}"
      end

      delete '/:disk_name', scope: :delete_dynamic_disks do
        disk_name = safe_property(params, 'disk_name', class: String, min_length: 1)

        task = JobQueue.new.enqueue(
          current_user,
          Jobs::DynamicDisks::DeleteDynamicDisk,
          'delete dynamic disk',
          [disk_name]
        )

        redirect "/tasks/#{task.id}"
      end
    end
  end
end
