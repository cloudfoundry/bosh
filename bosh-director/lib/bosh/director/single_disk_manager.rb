module Bosh::Director
  class SingleDiskManager

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

      if old_disk
        unmount_and_detach_disk(instance.model, old_disk)
        @orphan_disk_manager.orphan_disk(old_disk)
      end

      inactive_disks = Models::PersistentDisk.where(active: false, instance: instance.model)
      inactive_disks.each do |disk|
        detach_disk(instance.model, disk)
        @orphan_disk_manager.orphan_disk(disk)
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
        @orphan_disk_manager.orphan_disk(disk)
      end
    end

    def unmount_disk_for(instance_plan)
      disk = instance_plan.instance.model.persistent_disk
      return if disk.nil?
      unmount_disk(instance_plan.instance.model, disk)
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
      AgentClient.with_vm_credentials_and_agent_id(instance_model.credentials, instance_model.agent_id, instance_model.name)
    end

    def create_and_attach_disk(instance_plan)
      disks = create_disk(instance_plan)
      disks.first
    end

    def mount_and_migrate_disk(instance, new_disk, old_disk)
      agent_client = agent_client(instance.model)
      agent_client.mount_disk(new_disk.disk_cid)
      # Mirgate to and from cids are actually ignored by the agent.
      # The first mount invocation is the source, and the last mount invocation is the target.
      agent_client.migrate_disk(old_disk.disk_cid, new_disk.disk_cid) if old_disk
    rescue => e
      @logger.debug("Failed to migrate disk, deleting new disk. #{e.inspect}")

      unmount_and_detach_disk(instance.model, new_disk)
      @orphan_disk_manager.orphan_disk(new_disk)
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

    def create_disk(instance_plan)
      disks = []
      job = instance_plan.desired_instance.instance_group
      instance_model = instance_plan.instance.model
      parent_id = add_event('create', instance_model.deployment.name, "#{instance_model.job}/#{instance_model.uuid}")

      @disk_creator = DeploymentPlan::DiskCreator.new(@cloud, instance_model.vm_cid)
      disks = job.persistent_disk_collection.create_disks(@disk_creator, instance_model.id)
      disks
    rescue Exception => e
      raise e
    ensure
      disk_cid = disks.empty? ? nil : disks.first.disk_cid
      add_event('create', instance_model.deployment.name, "#{instance_model.job}/#{instance_model.uuid}", disk_cid, parent_id, e)
    end
  end
end
