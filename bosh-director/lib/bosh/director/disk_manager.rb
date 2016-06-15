module Bosh::Director
  class DiskManager

    def initialize(cloud, logger)
      @cloud = cloud
      @logger = logger
      @transactor = Transactor.new
    end

    def update_persistent_disk(instance_plan)
      @logger.info('Updating persistent disk')
      check_persistent_disk(instance_plan)

      return unless instance_plan.persistent_disk_changed?

      instance = instance_plan.instance
      old_disk = instance.model.persistent_disk

      disk = nil
      if instance_plan.needs_disk?
        disk = create_and_attach_disk(instance_plan)
        mount_and_migrate_disk(instance, disk, old_disk)
      end

      @transactor.retryable_transaction(Bosh::Director::Config.db) do
        old_disk.update(:active => false) if old_disk
        disk.update(:active => true) if disk
      end

      orphan_mounted_persistent_disk(instance.model, old_disk) if old_disk

      inactive_disks = Models::PersistentDisk.where(active: false, instance: instance.model)
      inactive_disks.each do |disk|
        detach_disk(instance.model, disk)
        orphan_disk(disk)
      end
    end

    def attach_disks_if_needed(instance_plan)
      unless instance_plan.needs_disk?
        @logger.warn('Skipping disk attachment, instance no longer needs disk')
        return
      end
      attach_disk(instance_plan.instance.model)
    end

    def delete_persistent_disks(instance_model)
      instance_model.persistent_disks.each do |disk|
        orphan_disk(disk)
      end
    end

    def orphan_disk(disk)
      @transactor.retryable_transaction(Bosh::Director::Config.db) do
        begin
          parent_id = add_event('delete', disk.instance.deployment.name, "#{disk.instance.job}/#{disk.instance.uuid}", disk.disk_cid)
          orphan_disk = Models::OrphanDisk.create(
              disk_cid:          disk.disk_cid,
              size:              disk.size,
              availability_zone: disk.instance.availability_zone,
              deployment_name:   disk.instance.deployment.name,
              instance_name:     "#{disk.instance.job}/#{disk.instance.uuid}",
              cloud_properties:  disk.cloud_properties
          )

          orphan_snapshots(disk.snapshots, orphan_disk)
          @logger.info("Orphaning disk: '#{disk.disk_cid}', #{disk.active ? "active" : "inactive"}")
          disk.destroy
        rescue Exception => e
          raise e
        ensure
          add_event('delete', orphan_disk.deployment_name, orphan_disk.instance_name, orphan_disk.disk_cid, parent_id, e)
        end
      end
    end

    def unorphan_disk(disk, instance_id)
      @transactor.retryable_transaction(Bosh::Director::Config.db) do
        new_disk = Models::PersistentDisk.create(
            disk_cid: disk.disk_cid,
            instance_id: instance_id,
            active: true,
            size: disk.size,
            cloud_properties: disk.cloud_properties)

        disk.orphan_snapshots.each do |snapshot|
          Models::Snapshot.create(persistent_disk: new_disk, snapshot_cid: snapshot.snapshot_cid, clean: snapshot.clean)
          snapshot.destroy
        end

        disk.destroy
      end
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
          'orphaned_at' => disk.created_at.to_s
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

    def unmount_disk_for(instance_plan)
      disk = instance_plan.instance.model.persistent_disk
      return if disk.nil?
      unmount_disk(instance_plan.instance.model, disk)
    end

    def delete_orphan_disk(orphan_disk)
      begin
        orphan_disk.orphan_snapshots.each do |orphan_snapshot|
          delete_orphan_snapshot(orphan_snapshot)
        end
        @logger.info("Deleting orphan orphan disk: #{orphan_disk.disk_cid}")
        @cloud.delete_disk(orphan_disk.disk_cid)
        orphan_disk.destroy
      rescue Bosh::Clouds::DiskNotFound
        @logger.debug("Disk not found in IaaS: #{orphan_disk.disk_cid}")
        orphan_disk.destroy
      end
    end

    def attach_disk(instance_model)
      disk_cid = instance_model.persistent_disk_cid
      return @logger.info('Skipping disk attaching') if disk_cid.nil?

      begin
        @cloud.attach_disk(instance_model.vm_cid, disk_cid)
        agent_client(instance_model).mount_disk(disk_cid)
      rescue => e
        @logger.warn("Failed to attach disk to new VM: #{e.inspect}")
        raise e
      end
    end

    def detach_disk(instance_model, disk)
      begin
        @logger.info("Detaching disk #{disk.disk_cid}")
        @cloud.detach_disk(instance_model.vm_cid, disk.disk_cid)
      rescue Bosh::Clouds::DiskNotAttached
        if disk.active
          raise CloudDiskNotAttached,
                "'#{instance_model}' VM should have persistent disk attached " +
                    "but it doesn't (according to CPI)"
        end
      end
    end

    def unmount_disk(instance_model, disk)
      disk_cid = disk.disk_cid
      if disk_cid.nil?
        @logger.info('Skipping disk unmounting, instance does not have a disk')
        return
      end

      if agent_mounted_disks(instance_model).include?(disk_cid)
        @logger.info("Stopping instance '#{instance_model}' before unmount")
        agent_client(instance_model).stop
        @logger.info("Unmounting disk '#{disk_cid}'")
        agent_client(instance_model).unmount_disk(disk_cid)
      end
    end

    private

    def add_event(action, deployment_name, instance_name, object_name = nil, parent_id = nil, error = nil)
      event  = Config.current_job.event_manager.create_event(
          {
              parent_id:   parent_id,
              user:        Config.current_job.username,
              action:      action,
              object_type: 'disk',
              object_name: object_name,
              deployment:  deployment_name,
              instance:    instance_name,
              task:        Config.current_job.task_id,
              error:       error
          })
      event.id
    end

    def orphan_mounted_persistent_disk(instance_model, disk)
      unmount_disk(instance_model, disk)

      disk_cid = disk.disk_cid
      if disk_cid.nil?
        @logger.info('Skipping disk detaching, instance does not have a disk')
        return
      end

      detach_disk(instance_model, disk)
      orphan_disk(disk)
    end

    def delete_orphan_snapshot(orphan_snapshot)
      begin
        snapshot_cid = orphan_snapshot.snapshot_cid
        @logger.info("Deleting orphan snapshot: #{snapshot_cid}")
        @cloud.delete_snapshot(snapshot_cid)
        orphan_snapshot.destroy
      rescue Bosh::Clouds::DiskNotFound
        @logger.debug("Disk not found in IaaS: #{snapshot_cid}")
        orphan_snapshot.destroy
      end
    end

    def orphan_snapshots(snapshots, orphan_disk)
      snapshots.each do |snapshot|
        @logger.info("Orphaning snapshot: '#{snapshot.snapshot_cid}'")
        Models::OrphanSnapshot.create(
          orphan_disk: orphan_disk,
          snapshot_cid: snapshot.snapshot_cid,
          clean: snapshot.clean,
          snapshot_created_at: snapshot.created_at
        )
        snapshot.destroy
      end
    end

    # Synchronizes persistent_disks with the agent.
    # (Currently assumes that we only have 1 persistent disk.)
    # @return [void]
    def check_persistent_disk(instance_plan)
      instance = instance_plan.instance
      return if instance.model.persistent_disks.empty?
      agent_disk_cid = agent_mounted_disks(instance.model).first

      if agent_disk_cid.nil? && !instance_plan.needs_disk?
        @logger.debug('Disk is already detached')
      elsif agent_disk_cid != instance.model.persistent_disk_cid
        raise AgentDiskOutOfSync,
          "'#{instance}' has invalid disks: agent reports " +
            "'#{agent_disk_cid}' while director record shows " +
            "'#{instance.model.persistent_disk_cid}'"
      end

      instance.model.persistent_disks.each do |disk|
        unless disk.active
          @logger.warn("'#{instance}' has inactive disk #{disk.disk_cid}")
        end
      end
    end

    def agent_mounted_disks(instance_model)
      agent_client(instance_model).list_disk
    end

    def agent_client(instance_model)
      AgentClient.with_vm_credentials_and_agent_id(instance_model.credentials, instance_model.agent_id)
    end

    def create_and_attach_disk(instance_plan)
      instance = instance_plan.instance
      disk = create_disk(instance_plan)
      @cloud.attach_disk(instance.model.vm_cid, disk.disk_cid)
      disk
    end

    def mount_and_migrate_disk(instance, new_disk, old_disk)
      agent_client = agent_client(instance.model)
      agent_client.mount_disk(new_disk.disk_cid)
      # Mirgate to and from cids are actually ignored by the agent.
      # The first mount invocation is the source, and the last mount invocation is the target.
      agent_client.migrate_disk(old_disk.disk_cid, new_disk.disk_cid) if old_disk
    rescue => e
      @logger.debug("Failed to migrate disk, deleting new disk. #{e.inspect}")
      orphan_mounted_persistent_disk(instance.model, new_disk)
      raise e
    end

    def create_disk(instance_plan)
      job = instance_plan.desired_instance.job
      instance_model = instance_plan.instance.model
      parent_id = add_event('create', instance_model.deployment.name, "#{instance_model.job}/#{instance_model.uuid}")
      disk_size = job.persistent_disk_type.disk_size
      cloud_properties = job.persistent_disk_type.cloud_properties
      disk_cid = @cloud.create_disk(disk_size, cloud_properties, instance_model.vm_cid)

      Models::PersistentDisk.create(
        disk_cid: disk_cid,
        active: false,
        instance_id: instance_model.id,
        size: disk_size,
        cloud_properties: cloud_properties,
      )
    rescue Exception => e
      raise e
    ensure
      add_event('create', instance_model.deployment.name, "#{instance_model.job}/#{instance_model.uuid}", disk_cid, parent_id, e)
    end
  end
end
