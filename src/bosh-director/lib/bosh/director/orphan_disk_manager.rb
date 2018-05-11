module Bosh::Director
  class OrphanDiskManager
    def initialize(logger)
      @logger = logger
      @transactor = Transactor.new
    end

    def orphan_disk(disk)
      instance_name = "#{disk.instance.job}/#{disk.instance.uuid}"

      @transactor.retryable_transaction(Bosh::Director::Config.db) do
        begin
          parent_id = add_event('orphan', disk.instance.deployment.name, instance_name, disk.disk_cid)
          orphan_disk = Models::OrphanDisk.create(
            disk_cid:          disk.disk_cid,
            size:              disk.size,
            cpi:               disk.cpi,
            availability_zone: disk.instance.availability_zone,
            deployment_name:   disk.instance.deployment.name,
            instance_name:     instance_name,
            cloud_properties:  disk.cloud_properties,
          )

          orphan_snapshots(disk.snapshots, orphan_disk)
          @logger.info("Orphaning disk: '#{disk.disk_cid}', #{disk.active ? 'active' : 'inactive'}")
          disk.destroy
        rescue StandardError => e
          raise e
        ensure
          add_event(
            'orphan',
            disk.instance.deployment.name,
            instance_name,
            orphan_disk&.disk_cid,
            parent_id,
            e,
          )
        end
      end
    end

    def unorphan_disk(disk, instance_id)
      new_disk = nil

      @transactor.retryable_transaction(Bosh::Director::Config.db) do
        new_disk = Models::PersistentDisk.create(
          disk_cid: disk.disk_cid,
          instance_id: instance_id,
          active: true,
          size: disk.size,
          cloud_properties: disk.cloud_properties,
          cpi: disk.cpi,
        )

        disk.orphan_snapshots.each do |snapshot|
          Models::Snapshot.create(persistent_disk: new_disk, snapshot_cid: snapshot.snapshot_cid, clean: snapshot.clean)
          snapshot.destroy
        end

        disk.destroy
      end

      new_disk
    end

    def list_orphan_disks
      Models::OrphanDisk.all.map do |disk|
        {
          'disk_cid' => disk.disk_cid,
          'size' => disk.size,
          'az' => disk.availability_zone,
          'deployment_name' => disk.deployment_name,
          'instance_name' => disk.instance_name,
          'cloud_properties' => disk.cloud_properties,
          'orphaned_at' => disk.created_at.to_s,
        }
      end
    end

    def delete_orphan_disk_by_disk_cid(disk_cid)
      @logger.info("Deleting orphan disk: #{disk_cid}")
      orphan_disk = Models::OrphanDisk.where(disk_cid: disk_cid).first
      if orphan_disk
        delete_orphan_disk(orphan_disk)
      else
        @logger.debug("Disk not found: #{disk_cid}")
      end
    end

    def delete_orphan_disk(orphan_disk)
      delete_orphan_disk_snapshots(orphan_disk)

      begin
        instance_name = orphan_disk.instance_name
        deployment_name = orphan_disk.deployment_name
        orphan_disk_cid = orphan_disk.disk_cid
        parent_id = add_event('delete', deployment_name, instance_name, orphan_disk_cid)
        @logger.info("Deleting orphan orphan disk: #{orphan_disk.disk_cid}")
        cloud = CloudFactory.create.get(orphan_disk.cpi)
        cloud.delete_disk(orphan_disk.disk_cid)
        orphan_disk.destroy
      rescue Bosh::Clouds::DiskNotFound => e
        @logger.debug("Disk not found in IaaS: #{orphan_disk.disk_cid}")
        orphan_disk.destroy
      ensure
        add_event('delete', deployment_name, instance_name, orphan_disk_cid, parent_id, e)
      end
    end

    private

    def add_event(action, deployment_name, instance_name, object_name = nil, parent_id = nil, error = nil)
      event = Config.current_job.event_manager.create_event(
        parent_id:   parent_id,
        user:        Config.current_job.username,
        action:      action,
        object_type: 'disk',
        object_name: object_name,
        deployment:  deployment_name,
        instance:    instance_name,
        task:        Config.current_job.task_id,
        error:       error,
      )
      event.id
    end

    def delete_orphan_disk_snapshots(orphan_disk)
      failed_orphan_snapshot_count = 0
      orphan_disk.orphan_snapshots.each do |orphan_snapshot|
        begin
          delete_orphan_snapshot(orphan_snapshot)
        rescue StandardError => e
          failed_orphan_snapshot_count += 1
          @logger.warn(e.backtrace.join("\n"))
          @logger.info("Failed to deleted snapshot #{orphan_snapshot.snapshot_cid} disk " \
            "of #{orphan_disk.disk_cid}. Failed with: #{e.message}")
        end
      end

      return unless failed_orphan_snapshot_count.positive?

      raise Bosh::Clouds::CloudError, "Failed to delete #{failed_orphan_snapshot_count} " \
        "snapshot(s) of disk #{orphan_disk.disk_cid}"
    end

    def delete_orphan_snapshot(orphan_snapshot)
      snapshot_cid = orphan_snapshot.snapshot_cid
      @logger.info("Deleting orphan snapshot: #{snapshot_cid}")
      cloud = CloudFactory.create.get(orphan_snapshot.orphan_disk.cpi)
      cloud.delete_snapshot(snapshot_cid)
      orphan_snapshot.destroy
    rescue Bosh::Clouds::DiskNotFound
      @logger.debug("Disk not found in IaaS: #{snapshot_cid}")
      orphan_snapshot.destroy
    end

    def orphan_snapshots(snapshots, orphan_disk)
      snapshots.each do |snapshot|
        @logger.info("Orphaning snapshot: '#{snapshot.snapshot_cid}'")
        Models::OrphanSnapshot.create(
          orphan_disk: orphan_disk,
          snapshot_cid: snapshot.snapshot_cid,
          clean: snapshot.clean,
          snapshot_created_at: snapshot.created_at,
        )
        snapshot.destroy
      end
    end
  end
end
