module Bosh::Director
  class DiskManager
    def initialize(logger)
      @logger = logger
      @orphan_disk_manager = OrphanDiskManager.new(@logger)
      @transactor = Transactor.new
      @config_server_client = Bosh::Director::ConfigServer::ClientFactory.create(@logger).create_client
    end

    def update_persistent_disk(instance_plan)
      @logger.info('Updating persistent disk')

      check_persistent_disk(instance_plan) unless has_multiple_persistent_disks?(instance_plan)

      return unless instance_plan.persistent_disk_changed?

      instance_model = instance_plan.instance.model
      new_disks = instance_plan.desired_instance.instance_group.persistent_disk_collection
      old_disks = instance_model.active_persistent_disks

      changed_disk_pairs = Bosh::Director::DeploymentPlan::PersistentDiskCollection.changed_disk_pairs(
        old_disks,
        instance_plan.instance.previous_variable_set,
        new_disks,
        instance_plan.instance.desired_variable_set,
      )

      changed_disk_pairs.each do |disk_pair|
        new_disk = disk_pair[:new]
        old_disk = disk_pair[:old]

        @logger.info("CPI resize disk enabled: #{Config.enable_cpi_resize_disk}")

        if use_cpi_resize_disk?(old_disk, new_disk)
          resize_disk(instance_plan, new_disk, old_disk)
        else
          update_disk(instance_plan, new_disk, old_disk)
        end

      end

      inactive_disks = Models::PersistentDisk.where(active: false, instance: instance_model)
      inactive_disks.each do |disk|
        detach_disk(disk)
        @orphan_disk_manager.orphan_disk(disk)
      end
    end

    def attach_disks_if_needed(instance_plan)
      unless instance_plan.needs_disk?
        @logger.warn('Skipping disk attachment, instance no longer needs disk')
        return
      end

      instance_plan.instance.model.active_persistent_disks.collection.each do |disk|
        attach_disk(disk.model, instance_plan.tags)
      end
    end

    def delete_persistent_disks(instance_model)
      instance_model.persistent_disks.each do |disk|
        @orphan_disk_manager.orphan_disk(disk)
      end
    end

    def unmount_disk_for(instance_plan)
      instance_model = instance_plan.instance.model
      instance_model.active_persistent_disks.select(&:managed?).each do |disk|
        unmount_disk(disk.model)
      end
    end

    def attach_disk(disk, tags)
      cloud = cloud_for_cpi(disk.instance.active_vm.cpi)
      vm_cid = disk.instance.vm_cid
      cloud.attach_disk(vm_cid, disk.disk_cid)
      MetadataUpdater.build.update_disk_metadata(cloud, disk, tags)
      mount_disk(disk) if disk.managed?
    end

    def detach_disk(disk)
      instance_model = disk.instance
      unmount_disk(disk) if disk.managed?
      begin
        @logger.info("Detaching disk #{disk.disk_cid}")
        cloud = cloud_for_cpi(instance_model.active_vm.cpi)
        vm_cid = instance_model.vm_cid
        cloud.detach_disk(vm_cid, disk.disk_cid)
      rescue Bosh::Clouds::DiskNotAttached
        if disk.active
          raise CloudDiskNotAttached,
                "'#{instance_model}' VM should have persistent disk attached " +
                    "but it doesn't (according to CPI)"
        end
      end
    end

    def unmount_disk(disk)
      instance_model = disk.instance
      disk_cid = disk.disk_cid
      if disk_cid.nil?
        @logger.info('Skipping disk unmounting, instance does not have a disk')
        return
      end

      if agent_mounted_disks(instance_model).include?(disk_cid)
        @logger.info("Unmounting disk '#{disk_cid}'")
        agent_client(instance_model).unmount_disk(disk_cid)
      end
    end

    private

    def use_cpi_resize_disk?(old_disk, new_disk)
      Config.enable_cpi_resize_disk && new_disk && new_disk.size_diff_only?(old_disk) && new_disk.managed?
    end

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
      elsif agent_disk_cid != instance.model.managed_persistent_disk_cid
        raise AgentDiskOutOfSync,
          "'#{instance}' has invalid disks: agent reports " +
            "'#{agent_disk_cid}' while director record shows " +
            "'#{instance.model.managed_persistent_disk_cid}'"
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

    def mount_disk(disk)
      agent_client = agent_client(disk.instance)
      agent_client.wait_until_ready
      agent_client.mount_disk(disk.disk_cid)
    rescue => e
      @logger.debug("Failed to mount disk, deleting new disk. #{e.inspect}")

      unmount_and_detach_disk(disk)
      raise e
    end

    def migrate_disk(instance_model, disk, old_disk)
      agent_client = agent_client(instance_model)
      # Mirgate to and from cids are actually ignored by the agent.
      # The first mount invocation is the source, and the last mount invocation is the target.
      agent_client.migrate_disk(old_disk.disk_cid, disk.disk_cid)
    rescue => e
      @logger.debug("Failed to migrate disk, deleting new disk. #{e.inspect}")

      unmount_and_detach_disk(disk)
      @orphan_disk_manager.orphan_disk(disk)
      raise e
    end

    def has_multiple_persistent_disks?(instance_plan)
      !instance_plan.desired_instance.instance_group.persistent_disk_collection.non_managed_disks.empty?
    end

    def unmount_and_detach_disk(disk)
      unmount_disk(disk)

      disk_cid = disk.disk_cid
      if disk_cid.nil?
        @logger.info('Skipping disk detaching, instance does not have a disk')
        return
      end

      detach_disk(disk)
    end

    def create_disk(instance, disk)
      disk_size = disk.size
      disk_model = nil
      instance_model = instance.model

      cloud_properties = @config_server_client.interpolate_with_versioning(disk.cloud_properties, instance.desired_variable_set)

      begin
        parent_id = add_event('create', instance_model.deployment.name, "#{instance_model.job}/#{instance_model.uuid}")

        cloud = cloud_for_cpi(instance_model.active_vm.cpi)
        disk_cid = cloud.create_disk(disk_size, cloud_properties, instance_model.vm_cid)

        disk_model = Models::PersistentDisk.create(
          name: disk.name,
          disk_cid: disk_cid,
          active: false,
          instance_id: instance_model.id,
          size: disk_size,
          cloud_properties: disk.cloud_properties,
          cpi: instance_model.active_vm.cpi
        )
      rescue Exception => e
        raise e
      ensure
        add_event('create', instance_model.deployment.name, "#{instance_model.job}/#{instance_model.uuid}", disk_cid, parent_id, e)
      end

      disk_model
    end

    def update_disk(instance_plan, new_disk, old_disk)
      old_disk_model = old_disk.model unless old_disk.nil?
      new_disk_model = nil

      if new_disk
        instance_model = instance_plan.instance.model
        new_disk_model = create_disk(instance_plan.instance, new_disk)

        attach_disk(new_disk_model, instance_plan.tags)

        if new_disk.managed? && old_disk_model
          migrate_disk(instance_model, new_disk_model, old_disk_model)
        end
      end

      @transactor.retryable_transaction(Bosh::Director::Config.db) do
        old_disk_model.update(:active => false) if old_disk_model
        new_disk_model.update(:active => true) if new_disk_model
      end

      if old_disk_model
        detach_disk(old_disk_model)

        @orphan_disk_manager.orphan_disk(old_disk_model)
      end
    end

    def resize_disk(instance_plan, new_disk, old_disk)
      @logger.info("Starting IaaS native disk resize #{old_disk.model.disk_cid}")
      detach_disk(old_disk.model)

      begin
        cloud_resize_disk(old_disk.model, new_disk.size)
      rescue Bosh::Clouds::NotImplemented, Bosh::Clouds::NotSupported => e
        @logger.info("IaaS native disk resize not possible for #{old_disk.model.disk_cid}. Falling back to copy disk.\n#{e.message}")
        attach_disk(old_disk.model, instance_plan.tags)
        update_disk(instance_plan, new_disk, old_disk)
        return
      end

      attach_disk(old_disk.model, instance_plan.tags)
      old_disk.model.update(:size => new_disk.size)
      @logger.info("Finished IaaS native disk resize #{old_disk.model.disk_cid}")
    end

    def cloud_resize_disk(old_disk_model, new_disk_size)
      cloud = cloud_for_cpi(old_disk_model.instance.active_vm.cpi)
      cloud.resize_disk(old_disk_model.disk_cid, new_disk_size)
    end

    def cloud_for_cpi(cpi)
      cloud_factory = CloudFactory.create_with_latest_configs
      cloud_factory.get(cpi)
    end
  end
end
