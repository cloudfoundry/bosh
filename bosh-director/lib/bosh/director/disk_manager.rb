module Bosh::Director
  class DiskManager

    def initialize(cloud, logger)
      @cloud = cloud
      @logger = logger
      @orphan_disk_manager = OrphanDiskManager.new(@cloud, @logger)
      @transactor = Transactor.new
    end

    def update_persistent_disk(instance_plan)
      @logger.info('Updating persistent disk')
      check_persistent_disk(instance_plan)

      return unless instance_plan.persistent_disk_changed?

      instance_model = instance_plan.instance.model
      new_disks = instance_plan.desired_instance.instance_group.persistent_disk_collection
      old_disks = instance_model.active_persistent_disks

      changed_disk_pairs = new_disks.changed_disk_pairs(old_disks)

      changed_disk_pairs.each do |disk_pair|
        old_disk = disk_pair[:old]
        old_disk_model = old_disk.model unless old_disk.nil?

        new_disk = disk_pair[:new]
        new_disk_model = nil

        if new_disk
          new_disk_model = create_disk(instance_model, new_disk)

          attach_disk(new_disk_model)

          if new_disk.managed?
            mount_disk(instance_model, new_disk_model)

            if old_disk
              migrate_disk(instance_model, new_disk_model, old_disk_model)
            end
          end
        end

        @transactor.retryable_transaction(Bosh::Director::Config.db) do
          old_disk_model.update(:active => false) if old_disk_model
          new_disk_model.update(:active => true) if new_disk_model
        end

        if old_disk
          unmount_disk(instance_model, old_disk_model)
          detach_disk(instance_model, old_disk_model)

          @orphan_disk_manager.orphan_disk(old_disk_model)
        end
      end

      inactive_disks = Models::PersistentDisk.where(active: false, instance: instance_model)
      inactive_disks.each do |disk|
        detach_disk(instance_model, disk)
        @orphan_disk_manager.orphan_disk(disk)
      end
    end

    def attach_disks_if_needed(instance_plan)
      unless instance_plan.needs_disk?
        @logger.warn('Skipping disk attachment, instance no longer needs disk')
        return
      end

      instance_plan.instance.model.active_persistent_disks.collection.each do |disk|
        attach_disk(disk.model)
      end
    end

    def delete_persistent_disks(instance_model)
      instance_model.persistent_disks.each do |disk|
        @orphan_disk_manager.orphan_disk(disk)
      end
    end

    def unmount_disk_for(instance_plan)
      disk = instance_plan.instance.model.persistent_disk
      return if disk.nil?
      unmount_disk(instance_plan.instance.model, disk)
    end

    def attach_disk(disk)
      @cloud.attach_disk(disk.instance.vm_cid, disk.disk_cid)
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

    # @todo[multi-disks] the rescue is duplicated with migrate_disk
    def mount_disk(instance_model, disk)
      agent_client = agent_client(instance_model)
      agent_client.mount_disk(disk.disk_cid)
    rescue => e
      @logger.debug("Failed to mount disk, deleting new disk. #{e.inspect}")

      unmount_and_detach_disk(instance_model, disk)
      @orphan_disk_manager.orphan_disk(disk)
      raise e
    end

    def migrate_disk(instance_model, disk, old_disk)
      agent_client = agent_client(instance_model)
      # Mirgate to and from cids are actually ignored by the agent.
      # The first mount invocation is the source, and the last mount invocation is the target.
      agent_client.migrate_disk(old_disk.disk_cid, disk.disk_cid)
    rescue => e
      @logger.debug("Failed to migrate disk, deleting new disk. #{e.inspect}")

      unmount_and_detach_disk(instance_model, disk)
      @orphan_disk_manager.orphan_disk(disk)
      raise e
    end

    def unmount_and_detach_disk(instance_model, disk)
      unmount_disk(instance_model, disk)

      disk_cid = disk.disk_cid
      if disk_cid.nil?
        @logger.info('Skipping disk detaching, instance does not have a disk')
        return
      end

      detach_disk(instance_model, disk)
    end

    def create_disk(instance_model, disk)
      disk_size = disk.size
      cloud_properties = disk.cloud_properties
      disk_model = nil

      begin
        parent_id = add_event('create', instance_model.deployment.name, "#{instance_model.job}/#{instance_model.uuid}")

        disk_cid = @cloud.create_disk(disk_size, cloud_properties, instance_model.vm_cid)

        disk_model = Models::PersistentDisk.create(
          name: disk.name,
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

      disk_model
    end

    def create_disks(instance_plan)
      job = instance_plan.desired_instance.instance_group.persistent_disk_collection
      instance_model = instance_plan.instance.model

      disks = job.persistent_disk_collection.collection.map do |disk|
        disk_size = disk.size
        cloud_properties = disk.cloud_properties
        disk_model = nil

        begin
          parent_id = add_event('create', instance_model.deployment.name, "#{instance_model.job}/#{instance_model.uuid}")

          disk_cid = @cloud.create_disk(disk_size, cloud_properties, instance_model.vm_cid)

          disk_model = Models::PersistentDisk.create(
            name: disk.name,
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

        disk_model
      end

      disks
    end
  end
end
