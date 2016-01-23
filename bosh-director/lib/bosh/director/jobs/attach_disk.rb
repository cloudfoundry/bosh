module Bosh::Director
  module Jobs
    class AttachDisk < BaseJob

      @queue = :normal

      def self.job_type
        :attach_disk
      end

      def self.enqueue(username, deployment_name, job_name, instance_id, disk_cid, job_queue)
        job_queue.enqueue(username, Jobs::AttachDisk, "attach disk '#{disk_cid}' to '#{job_name}/#{instance_id}'", [deployment_name, job_name, instance_id, disk_cid])
      end

      def initialize(deployment_name, job_name, instance_id, disk_cid)
        @deployment_name = deployment_name
        @job_name = job_name
        @instance_id = instance_id
        @disk_cid = disk_cid
        @transactor = Transactor.new
      end

      def perform
        instance = Models::Instance.filter(job: @job_name, uuid: @instance_id).to_a.first

        if instance.nil? || instance.deployment.name != @deployment_name
          raise AttachDiskErrorUnknownInstance, "Instance '#{@job_name}/#{@instance_id}' in deployment '#{@deployment_name}' was not found"
        end

        if instance.persistent_disk.nil?
          raise AttachDiskNoPersistentDisk, "Job '#{@job_name}' is not configured with a persistent disk"
        end

        if instance.state != 'detached'
          raise AttachDiskInvalidInstanceState, "Instance '#{@job_name}/#{@instance_id}' in deployment '#{@deployment_name}' must be in 'bosh stopped --hard' state"
        end

        @transactor.retryable_transaction(instance.db) do
          instance.persistent_disk.update(active: false)
          Models::PersistentDisk.create(disk_cid: @disk_cid, instance_id: instance.id, active: true, size: 1, cloud_properties: {})
        end

        "attached disk '#{@disk_cid}' to '#{@job_name}/#{@instance_id}' in deployment '#{@deployment_name}'"
      end
    end
  end
end
