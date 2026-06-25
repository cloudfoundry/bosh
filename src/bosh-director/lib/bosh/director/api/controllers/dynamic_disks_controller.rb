require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class DynamicDisksController < BaseController
      include ValidationHelper

      get '/', scope: :list_dynamic_disks do
        disks = Models::DynamicDisk.eager(:deployment, vm: :instance).all.map do |disk|
          {
            name: disk.name,
            disk_cid: disk.disk_cid,
            deployment: disk.deployment&.name,
            instance: disk.vm&.instance&.name,
            availability_zone: disk.availability_zone,
            size: disk.size,
            disk_pool_name: disk.disk_pool_name,
            cpi: disk.cpi,
            metadata: disk.metadata,
          }
        end
        json_encode(disks)
      end

      post '/', scope: :create_dynamic_disks, consumes: :json do
        request_hash = JSON.parse(request.body.read)

        deployment_name = safe_property(request_hash, 'deployment_name', class: String, min_length: 1)
        az              = safe_property(request_hash, 'az', class: String, min_length: 1)
        disk_name       = safe_property(request_hash, 'disk_name', class: String, min_length: 1)
        disk_pool_name  = safe_property(request_hash, 'disk_pool_name', class: String, min_length: 1)
        disk_size       = safe_property(request_hash, 'disk_size', class: Integer, min: 1)
        metadata        = safe_property(request_hash, 'metadata', class: Hash, optional: true)

        task = JobQueue.new.enqueue(
          current_user,
          Jobs::DynamicDisks::CreateDynamicDisk,
          'create dynamic disk',
          [deployment_name, az, disk_name, disk_pool_name, disk_size, metadata],
        )

        redirect "/tasks/#{task.id}"
      end

      post '/:disk_name/attach', scope: :attach_dynamic_disks, consumes: :json do
        disk_name = safe_property(params, 'disk_name', class: String, min_length: 1)

        request_hash = JSON.parse(request.body.read)
        instance_id = safe_property(request_hash, 'instance_id', class: String, min_length: 1)
        metadata = safe_property(request_hash, 'metadata', class: Hash, optional: true)

        task = JobQueue.new.enqueue(
          current_user,
          Jobs::DynamicDisks::AttachDynamicDisk,
          'attach dynamic disk',
          [disk_name, instance_id, metadata],
        )

        redirect "/tasks/#{task.id}"
      end

      post '/provide', scope: :provide_dynamic_disks, consumes: :json do
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

      post '/:disk_name/detach', scope: :detach_dynamic_disks do
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
