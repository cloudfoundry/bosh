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
          orphan_disk = Models::OrphanDisk[:disk_cid => @disk_cid]

          if orphan_disk
            current_disk = Models::PersistentDisk[instance_id: instance.id]

            if current_disk
              create_orphan_disk_from_current_disk(current_disk)
            end

            create_new_disk_from_orphan_disk(orphan_disk, instance)
          else
            Models::PersistentDisk.create(disk_cid: @disk_cid, instance_id: instance.id, active: true, size: 1, cloud_properties: {})
          end

        end

        "attached disk '#{@disk_cid}' to '#{@job_name}/#{@instance_id}' in deployment '#{@deployment_name}'"
      end

      private

      def create_orphan_disk_from_current_disk(current_disk)
        new_orphan_disk = Models::OrphanDisk.create(disk_cid: current_disk.disk_cid,
                                                    size: current_disk.size,
                                                    availability_zone: current_disk.instance.availability_zone,
                                                    deployment_name: current_disk.instance.deployment.name,
                                                    instance_name: current_disk.instance.name,
                                                    cloud_properties: current_disk.cloud_properties)

        current_disk.snapshots.each do |snapshot|
          Models::OrphanSnapshot.create(orphan_disk: new_orphan_disk,
                                        snapshot_cid: snapshot.snapshot_cid,
                                        clean: snapshot.clean,
                                        snapshot_created_at: snapshot.created_at)
          snapshot.destroy
        end

        current_disk.destroy
      end

      def create_new_disk_from_orphan_disk(orphan_disk, instance)
        new_disk = Models::PersistentDisk.create(disk_cid: orphan_disk.disk_cid,
                                                 instance_id: instance.id,
                                                 active: true,
                                                 size: orphan_disk.size,
                                                 cloud_properties: orphan_disk.cloud_properties)

        orphan_disk.orphan_snapshots.each do |snapshot|
          Models::Snapshot.create(persistent_disk: new_disk, snapshot_cid: snapshot.snapshot_cid, clean: snapshot.clean)
          snapshot.destroy
        end

        orphan_disk.destroy
      end
    end
  end
end
