module Bosh::Director
  class DiskManager

    def initialize(cloud, logger)
      @cloud = cloud
      @logger = logger
    end

    def update_persistent_disk(instance_plan, vm_recreator)
      instance = instance_plan.instance

      attach_disks_for(instance) unless instance.disk_currently_attached?
      check_persistent_disk(instance)

      disk = nil
      return unless instance_plan.persistent_disk_changed?

      old_disk = instance.model.persistent_disk

      if instance.job.persistent_disk_type && instance.job.persistent_disk_type.disk_size > 0
        disk = create_and_attach_disk(instance_plan, vm_recreator)
        mount_and_migrate_disk(instance, disk, old_disk)
      end

      instance.model.db.transaction do
        old_disk.update(:active => false) if old_disk
        disk.update(:active => true) if disk
      end

      delete_mounted_persistent_disk(instance, old_disk) if old_disk
    end

    def attach_disks_for(instance)
      disk_cid = instance.model.persistent_disk_cid
      return @logger.info('Skipping disk attaching') if disk_cid.nil?
      vm_model = instance.vm.model
      begin
        @cloud.attach_disk(vm_model.cid, disk_cid)
        AgentClient.with_vm(vm_model).mount_disk(disk_cid)
      rescue => e
        @logger.warn("Failed to attach disk to new VM: #{e.inspect}")
        raise e
      end
    end

    def delete_persistent_disks(instance_model)
      instance_model.persistent_disks.each do |disk|
        orphan_disk(disk)
      end
    end

    def orphan_disk(disk)
      disk.db.transaction do
        orphan_disk = Models::OrphanDisk.create(
          disk_cid: disk.disk_cid,
          size: disk.size,
          availability_zone: disk.instance.availability_zone,
          deployment_name: disk.instance.deployment.name,
          instance_name: "#{disk.instance.job}/#{disk.instance.uuid}",
          cloud_properties_json: disk.cloud_properties
        )

        orphan_snapshots(disk.snapshots, orphan_disk)
        @logger.info("Orphaning disk: '#{disk.disk_cid}', " +
            "#{disk.active ? "active" : "inactive"}")

        disk.destroy
      end
    end

    def list_orphan_disks
      Models::OrphanDisk.all.map do |disk|
        {
          'disk_cid' => disk.disk_cid,
          'size' => disk.size || 'n/a',
          'availability_zone' => disk.availability_zone || 'n/a',
          'deployment_name' => disk.deployment_name,
          'instance_name' => disk.instance_name,
          'cloud_properties' => disk.cloud_properties.any? ? disk.cloud_properties : 'n/a',
          'orphaned_at' => disk.orphaned_at.to_s
        }
      end
    end

    private

    def orphan_snapshots(snapshots, orphan_disk)
      snapshots.each do |snapshot|
        Config.logger.info("Orphaning snapshot: '#{snapshot.snapshot_cid}'")
        Models::OrphanSnapshot.create(
          orphan_disk: orphan_disk,
          snapshot_cid: snapshot.snapshot_cid,
          clean: snapshot.clean,
          created_at: snapshot.created_at
        )
        snapshot.delete
      end
    end

    def delete_mounted_persistent_disk(instance, disk)
      disk_cid = disk.disk_cid
      vm_cid = instance.model.vm.cid

      # Unmount the disk only if disk is known by the agent
      if disks(instance).include?(disk_cid)
        agent(instance).unmount_disk(disk_cid)
      end

      begin
        @cloud.detach_disk(vm_cid, disk_cid) if vm_cid
      rescue Bosh::Clouds::DiskNotAttached
        if disk.active
          raise CloudDiskNotAttached,
            "`#{instance}' VM should have persistent disk attached " +
              "but it doesn't (according to CPI)"
        end
      end

      orphan_disk(disk)
    end

    # Synchronizes persistent_disks with the agent.
    # (Currently assumes that we only have 1 persistent disk.)
    # @return [void]
    def check_persistent_disk(instance)
      return if instance.model.persistent_disks.empty?
      agent_disk_cid = disks(instance).first

      if agent_disk_cid != instance.model.persistent_disk_cid
        raise AgentDiskOutOfSync,
          "`#{instance}' has invalid disks: agent reports " +
            "`#{agent_disk_cid}' while director record shows " +
            "`#{instance.model.persistent_disk_cid}'"
      end

      instance.model.persistent_disks.each do |disk|
        unless disk.active
          @logger.warn("`#{instance}' has inactive disk #{disk.disk_cid}")
        end
      end
    end

    def disks(instance)
      agent(instance).list_disk
    end

    def agent(instance)
      AgentClient.with_vm(instance.vm.model)
    end

    def create_and_attach_disk(instance_plan, vm_recreator)
      instance = instance_plan.instance
      disk = create_disk(instance)
      @cloud.attach_disk(instance.model.vm.cid, disk.disk_cid)
      return disk
    rescue Bosh::Clouds::NoDiskSpace => e
      if e.ok_to_retry
        @logger.warn('Retrying attach disk operation after persistent disk update failed')
        # Re-creating the vm may cause it to be re-created in a place with more storage
        vm_recreator.recreate_vm(instance_plan, disk.disk_cid)
        begin
          @cloud.attach_disk(instance.model.vm.cid, disk.disk_cid)
        rescue
          orphan_disk(disk)
          raise
        end
      else
        orphan_disk(disk)
        raise
      end
      return disk
    end

    def mount_and_migrate_disk(instance, new_disk, old_disk)
      agent(instance).mount_disk(new_disk.disk_cid)
      agent(instance).migrate_disk(old_disk.disk_cid, new_disk.disk_cid) if old_disk
    rescue
      delete_mounted_persistent_disk(instance, new_disk)
      raise
    end

    def create_disk(instance)
      disk_size = instance.job.persistent_disk_type.disk_size
      cloud_properties = instance.job.persistent_disk_type.cloud_properties

      disk = nil
      instance.model.db.transaction do
        disk_cid = @cloud.create_disk(disk_size, cloud_properties, instance.model.vm.cid)
        disk = Models::PersistentDisk.create(
          disk_cid: disk_cid,
          active: false,
          instance_id: instance.model.id,
          size: disk_size,
          cloud_properties: cloud_properties,
        )
      end
      disk
    end
  end
end
