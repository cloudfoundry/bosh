module Bosh::Director
  module Jobs
    class AttachDisk < BaseJob

      @queue = :normal

      def self.job_type
        :attach_disk
      end

      def self.enqueue(username, deployment, job_name, instance_id, disk_cid, job_queue)
        job_queue.enqueue(username, Jobs::AttachDisk, "attach disk '#{disk_cid}' to '#{job_name}/#{instance_id}'", [deployment.name, job_name, instance_id, disk_cid], deployment)
      end

      def initialize(deployment_name, job_name, instance_id, disk_cid)
        @deployment_name = deployment_name
        @job_name = job_name
        @instance_id = instance_id
        @disk_cid = disk_cid
        @transactor = Transactor.new
        @disk_manager = DiskManager.new(logger)
        @orphan_disk_manager = OrphanDiskManager.new(logger)
      end

      def perform
        instance = query_instance_model
        validate_instance(instance)

        @transactor.retryable_transaction(instance.db) do
          handle_previous_disk(instance) if instance.managed_persistent_disk
          handle_new_disk(instance)
        end

        "attached disk '#{@disk_cid}' to '#{@job_name}/#{@instance_id}' in deployment '#{@deployment_name}'"
      end

      private

      def query_instance_model
        Models::Instance.filter(job: @job_name, uuid: @instance_id).first
      end

      def validate_instance(instance)
        if instance.nil? || instance.deployment.name != @deployment_name
          raise AttachDiskErrorUnknownInstance, "Instance '#{@job_name}/#{@instance_id}' in deployment '#{@deployment_name}' was not found"
        end

        if instance.ignore
          raise AttachDiskInvalidInstanceState, "Instance '#{@job_name}/#{@instance_id}' in deployment '#{@deployment_name}' is in 'ignore' state. " +
              'Attaching disks to ignored instances is not allowed.'
        end

        if instance.state != 'detached' && instance.state != 'stopped'
          raise AttachDiskInvalidInstanceState, "Instance '#{@job_name}/#{@instance_id}' in deployment '#{@deployment_name}' must be in 'bosh stopped' state"
        end
      end

      def handle_previous_disk(instance)
        previous_persistent_disk = instance.managed_persistent_disk
        previous_persistent_disk.update(active: false)

        if instance.state == 'stopped'
          @disk_manager.detach_disk(previous_persistent_disk)
        end

        @orphan_disk_manager.orphan_disk(previous_persistent_disk)
      end

      def handle_new_disk(instance)
        orphan_disk = Models::OrphanDisk[:disk_cid => @disk_cid]
        if orphan_disk
          disk = @orphan_disk_manager.unorphan_disk(orphan_disk, instance.id)
        else
          disk = Models::PersistentDisk.create(disk_cid: @disk_cid, instance_id: instance.id, active: true, size: 1, cloud_properties: {})
        end

        if instance.state == 'stopped'
          @disk_manager.attach_disk(disk, instance.deployment.tags)
        end
      end
    end
  end
end
