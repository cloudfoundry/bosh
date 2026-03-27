module Bosh::Director
  class DiskManager
    def initialize(logger)
      @logger = logger
      @orphan_disk_manager = OrphanDiskManager.new(@logger)
      @transactor = Transactor.new
      @variables_interpolator = Bosh::Director::ConfigServer::VariablesInterpolator.new
    end

    def update_persistent_disk(instance_plan)
      @logger.info('Updating persistent disk')

      sync_persistent_disk(instance_plan) unless has_multiple_persistent_disks?(instance_plan)

      return unless instance_plan.persistent_disk_changed?

      instance_model = instance_plan.instance.model
      new_disks = instance_plan.desired_instance.instance_group.persistent_disk_collection
      old_disks = instance_model.active_persistent_disks

      changed_disk_pairs = Bosh::Director::DeploymentPlan::PersistentDiskCollection.changed_disk_pairs(
        old_disks,
        instance_plan.instance.previous_variable_set,
        new_disks,
        instance_plan.instance.desired_variable_set,
        instance_plan.recreate_persistent_disks_requested?,
      )

      changed_disk_pairs.each do |disk_pair|
        new_disk = disk_pair[:new]
        old_disk = disk_pair[:old]

        if use_iaas_native_disk_resize?(old_disk, new_disk)
          @logger.info("CPI is using native disk resize")
          resize_disk(instance_plan, new_disk, old_disk)
        elsif use_iaas_native_disk_update?(old_disk, new_disk)
          @logger.info("CPI is using native disk update")
          update_disk_cpi(instance_plan, new_disk, old_disk)
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

    # Called by RecreateHandler after disks are detached but before VM deletion.
    # Attempts to update disk types via CPI while disks are already in a detached state.
    # If the CPI doesn't support update_disk, changes are left for the post-recreation
    # update_persistent_disk call to handle via the standard copy path.
    def update_detached_disks(instance_plan)
      return unless Config.enable_cpi_update_disk
      return unless instance_plan.persistent_disk_changed?

      instance_model = instance_plan.instance.model
      new_disks = instance_plan.desired_instance.instance_group.persistent_disk_collection
      old_disks = instance_model.active_persistent_disks

      changed_disk_pairs = DeploymentPlan::PersistentDiskCollection.changed_disk_pairs(
        old_disks,
        instance_plan.instance.previous_variable_set,
        new_disks,
        instance_plan.instance.desired_variable_set,
      )

      changed_disk_pairs.each do |disk_pair|
        new_disk = disk_pair[:new]
        old_disk = disk_pair[:old]

        next unless new_disk && old_disk && new_disk.managed? && old_disk.managed?

        old_disk_model = old_disk.model
        next if old_disk_model.nil?

        active_vm = old_disk_model.instance.active_vm
        if active_vm.nil?
          @logger.warn("No active VM for disk '#{old_disk_model.disk_cid}', skipping CPI update")
          next
        end

        begin
          cloud = cloud_for_cpi(active_vm.cpi)
          resolved_cloud_properties = @variables_interpolator.interpolate_with_versioning(
            new_disk.cloud_properties,
            instance_plan.instance.desired_variable_set,
          )
          @logger.info("Updating detached disk '#{old_disk_model.disk_cid}' via CPI")
          new_disk_cid = cloud.update_disk(old_disk_model.disk_cid, new_disk.size, resolved_cloud_properties)

          updates = { size: new_disk.size, cloud_properties: new_disk.cloud_properties }
          if new_disk_cid && new_disk_cid != old_disk_model.disk_cid
            @logger.info("Disk CID changed from '#{old_disk_model.disk_cid}' to '#{new_disk_cid}'")
            updates[:disk_cid] = new_disk_cid
          end

          old_disk_model.update(updates)
          @logger.info("Successfully updated detached disk '#{old_disk_model.disk_cid}'")
        rescue Bosh::Clouds::NotImplemented, Bosh::Clouds::NotSupported => e
          # Only catch "not available" errors. Other CPI errors (e.g. partial failures during
          # snapshot-based migration) must propagate — the CPI may have replaced the disk and
          # swallowing the error would lose the new disk CID.
          @logger.info("CPI does not support update_disk for '#{old_disk_model.disk_cid}': #{e.message}. " \
                       "Will use copy path after VM recreation.")
        end
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

    def delete_dynamic_disk(disk)
      DeploymentPlan::Steps::DeleteDynamicDiskStep.new(disk).perform(step_report)
    end

    def attach_disk(disk, tags)
      report = step_report
      DeploymentPlan::Steps::AttachDiskStep.new(disk, tags).perform(report)
      mount_disk(disk, report) if disk.managed?
    end

    def detach_disk(disk)
      unmount_disk(disk) if disk.managed?
      DeploymentPlan::Steps::DetachDiskStep.new(disk).perform(step_report)
    end

    def unmount_disk(disk)
      DeploymentPlan::Steps::UnmountDiskStep.new(disk).perform(step_report)
    end

    private

    def step_report
      DeploymentPlan::Stages::Report.new
    end

    def use_iaas_native_disk_resize?(old_disk, new_disk)
      Config.enable_cpi_resize_disk &&
        new_disk &&
        new_disk.managed? &&
        new_disk.size_diff_only?(old_disk) &&
        new_disk.is_bigger_than?(old_disk)
    end

    def use_iaas_native_disk_update?(old_disk, new_disk)
      Config.enable_cpi_update_disk &&
        new_disk &&
        old_disk &&
        new_disk.managed? &&
        old_disk.managed?
    end

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

    # Synchronizes persistent_disks with the agent.
    # (Currently assumes that we only have 1 persistent disk.)
    # @return [void]
    def sync_persistent_disk(instance_plan)
      instance = instance_plan.instance
      return if instance.model.persistent_disks.empty?

      agent_disk_cid = agent_mounted_disks(instance.model).first

      if agent_disk_cid.nil? && !instance_plan.needs_disk?
        @logger.debug('Disk is already detached')
      elsif agent_disk_cid != instance.model.managed_persistent_disk_cid
        handle_disk_mismatch(agent_disk_cid, instance, instance_plan)
      end

      instance.model.persistent_disks.each do |disk|
        unless disk.active
          @logger.warn("'#{instance}' has inactive disk #{disk.disk_cid}")
        end
      end
    end

    def handle_disk_mismatch(agent_disk_cid, instance, instance_plan)
      if agent_disk_cid.nil?
        @logger.warn("Agent of '#{instance}' reports no disk while director record shows " \
                     "'#{instance.model.managed_persistent_disk_cid}'. " \
                     'Re-attaching existing persistent disk...')
        attach_disks_if_needed(instance_plan)
      else
        raise AgentDiskOutOfSync,
              "'#{instance}' has invalid disks: agent reports " \
              "'#{agent_disk_cid}' while director record shows " \
              "'#{instance.model.managed_persistent_disk_cid}'"
      end
    end

    def agent_mounted_disks(instance_model)
      agent_client(instance_model).list_disk
    end

    def agent_client(instance_model)
      AgentClient.with_agent_id(instance_model.agent_id, instance_model.name)
    end

    def mount_disk(disk, report = step_report)
      DeploymentPlan::Steps::MountDiskStep.new(disk).perform(report)
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

      cloud_properties = @variables_interpolator.interpolate_with_versioning(disk.cloud_properties, instance.desired_variable_set)

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
          cpi: instance_model.active_vm.cpi,
        )
      rescue Exception => e
        raise e
      ensure
        add_event(
          'create',
          instance_model.deployment.name,
          "#{instance_model.job}/#{instance_model.uuid}",
          disk_cid,
          parent_id,
          e,
        )
      end

      disk_model
    end

    def update_disk_cpi(instance_plan, new_disk, old_disk)
      old_disk_model = old_disk&.model
      if old_disk_model.nil?
        @logger.info("Perform disk create or update, as disk was not found.")
        update_disk(instance_plan, new_disk, old_disk)
        return
      end

      if old_disk_model.size == new_disk.size && old_disk_model.cloud_properties == new_disk.cloud_properties
        @logger.info("Disk '#{old_disk_model.disk_cid}' already matches desired state, skipping CPI update")
        return
      end

      @logger.info("Starting IaaS native update of disk '#{old_disk_model.disk_cid}' with new size '#{new_disk.size}' and cloud properties '#{new_disk.cloud_properties}'")
      detach_disk(old_disk_model)

      begin
        cloud = cloud_for_cpi(old_disk_model.instance.active_vm.cpi)
        resolved_cloud_properties = @variables_interpolator.interpolate_with_versioning(
          new_disk.cloud_properties,
          instance_plan.instance.desired_variable_set,
        )
        new_disk_cid = cloud.update_disk(old_disk_model.disk_cid, new_disk.size, resolved_cloud_properties)
      rescue Bosh::Clouds::NotImplemented, Bosh::Clouds::NotSupported => e
        @logger.info("IaaS native update not possible for disk #{old_disk_model.disk_cid}. Falling back to creating new disk.\n#{e.message}")
        attach_disk(old_disk_model, instance_plan.tags)
        update_disk(instance_plan, new_disk, old_disk)
        return
      end

      updates = { size: new_disk.size, cloud_properties: new_disk.cloud_properties }
      if new_disk_cid && new_disk_cid != old_disk_model.disk_cid
        @logger.info("Disk CID changed from '#{old_disk_model.disk_cid}' to '#{new_disk_cid}' after IaaS update")
        updates[:disk_cid] = new_disk_cid
      end

      attach_disk(old_disk_model, instance_plan.tags)

      old_disk_model.update(updates)
      @logger.info("Finished IaaS native update of disk '#{old_disk_model.disk_cid}'")
    end

    def update_disk(instance_plan, new_disk, old_disk)
      old_disk_model = old_disk&.model
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
        old_disk_model&.update(active: false)
        new_disk_model&.update(active: true)
      end

      return if old_disk_model.nil?

      detach_disk(old_disk_model)
      @orphan_disk_manager.orphan_disk(old_disk_model)
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
      old_disk.model.update(size: new_disk.size)
      @logger.info("Finished IaaS native disk resize #{old_disk.model.disk_cid}")
    end

    def cloud_resize_disk(old_disk_model, new_disk_size)
      cloud = cloud_for_cpi(old_disk_model.instance.active_vm.cpi)
      cloud.resize_disk(old_disk_model.disk_cid, new_disk_size)
    end

    def cloud_for_cpi(cpi)
      cloud_factory = CloudFactory.create
      cloud_factory.get(cpi)
    end
  end
end
