require 'bosh/director/rendered_job_templates_cleaner'

module Bosh::Director
  class InstanceUpdater
    WATCH_INTERVALS = 10
    MAX_RECREATE_ATTEMPTS = 3

    attr_reader :current_state

    def self.create(job_renderer)
      cloud = Config.cloud
      logger = Config.logger

      vm_deleter = Bosh::Director::VmDeleter.new(cloud, logger)
      vm_creator = Bosh::Director::VmCreator.new(cloud, logger, vm_deleter)
      dns_manager = DnsManager.create
      new(
        job_renderer,
        App.instance.blobstores.blobstore,
        vm_deleter,
        vm_creator,
        dns_manager,
        cloud,
        logger
      )
    end

    def initialize(
      job_renderer,
      blobstore,
      vm_deleter,
      vm_creator,
      dns_manager,
      cloud,
      logger
    )
      @job_renderer = job_renderer

      @cloud = cloud
      @logger = logger
      @blobstore = blobstore

      @vm_deleter = vm_deleter
      @vm_creator = vm_creator
      @dns_manager = dns_manager

      @current_state = {}
    end

    def update(instance_plan, options = {})
      instance = instance_plan.instance
      @logger.info("Updating instance #{instance}, changes: #{instance_plan.changes.to_a.join(', ').inspect}")

      @canary = options.fetch(:canary, false)

      # Optimization to only update DNS if nothing else changed.
      if dns_change_only?(instance_plan)
        @logger.debug('Only change is DNS configuration')
        update_dns(instance_plan)
        update_model(instance_plan)
        return
      end

      only_trusted_certs_changed = trusted_certs_change_only?(instance_plan) # figure this out before we start changing things

      Preparer.new(instance_plan, agent(instance), @logger).prepare
      stop(instance_plan)
      take_snapshot(instance)

      if instance.state == 'detached'
        @logger.info("Detaching instance #{instance}")
        @vm_deleter.delete_for_instance_plan(instance_plan)
        instance_plan.release_obsolete_ips
        instance.update_state
        update_model(instance_plan)
        return
      end

      unless try_to_update_in_place(instance_plan)
        @logger.debug('Failed to update in place. Recreating VM')
        recreate_vm(instance_plan, nil)
      end
      instance_plan.release_obsolete_ips

      update_dns(instance_plan)
      update_model(instance_plan)
      update_persistent_disk(instance_plan)

      if only_trusted_certs_changed
        @logger.debug('Skipping apply, trusted certs change only')
      else
        apply_state(instance)
      end

      if instance.state == 'started'
        run_pre_start_scripts(instance)
        start!(instance)
      end
      instance.update_state

      wait_until_running(instance)

      if instance.state == "started" && current_state["job_state"] != "running"
        raise AgentJobNotRunning, "`#{instance}' is not running after update"
      end

      if instance.state == "stopped" && current_state["job_state"] == "running"
        raise AgentJobNotStopped, "`#{instance}' is still running despite the stop command"
      end
    end

    private

    def run_pre_start_scripts(instance)
      agent(instance).run_script("pre-start", {})
    end

    def start!(instance)
      agent(instance).start
    rescue RuntimeError => e
      # FIXME: this is somewhat ghetto: we don't have a good way to
      # negotiate on BOSH protocol between director and agent (yet),
      # so updating from agent version that doesn't support 'start' RPC
      # to the one that does might be hard. Right now we decided to
      # just swallow the exception.
      # This needs to be removed in one of the following cases:
      # 1. BOSH protocol handshake gets implemented
      # 2. All agents updated to support 'start' RPC
      #    and we no longer care about backward compatibility.
      @logger.warn("agent start raised an exception: #{e.inspect}, ignoring for compatibility")
    end

    def trusted_certs_change_only?(instance_plan)
      instance_plan.changes.include?(:trusted_certs) && instance_plan.changes.size == 1
    end

    def stop(instance_plan)
      instance = instance_plan.instance
      skip_drain = deployment_plan(instance).skip_drain_for_job?(instance.job.name)
      stopper = Stopper.new(instance_plan, instance.state, skip_drain, Config, @logger)
      stopper.stop
    end

    def take_snapshot(instance)
      Api::SnapshotManager.take_snapshot(instance.model, clean: true)
    end

    def delete_snapshots(disk)
      Api::SnapshotManager.delete_snapshots(disk.snapshots)
    end

    def apply_state(instance)
      instance.apply_vm_state
      RenderedJobTemplatesCleaner.new(instance.model, @blobstore).clean
    end

    # Retrieve list of mounted disks from the agent
    # @return [Array<String>] list of disk CIDs
    def disk_info(instance)
      return @disk_list if @disk_list

      begin
        @disk_list = agent(instance).list_disk
      rescue RuntimeError
        # old agents don't support list_disk rpc
        [instance.persistent_disk_cid]
      end
    end

    def delete_unused_disk(disk)
      @cloud.delete_disk(disk.disk_cid)
      disk.destroy
    end

    def delete_mounted_disk(instance, disk)
      disk_cid = disk.disk_cid
      vm_cid = instance.model.vm.cid

      # Unmount the disk only if disk is known by the agent
      if agent(instance) && disk_info(instance).include?(disk_cid)
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

      delete_snapshots(disk)

      begin
        @cloud.delete_disk(disk_cid)
      rescue Bosh::Clouds::DiskNotFound
        if disk.active
          raise CloudDiskMissing,
            "Disk `#{disk_cid}' is missing according to CPI but marked " +
              "as active in DB"
        end
      end

      disk.destroy
    end

    def update_model(instance_plan)
      instance = instance_plan.instance
      desired_instance = instance_plan.desired_instance
      instance.model.update(
        job: desired_instance.job.name,
        bootstrap: desired_instance.bootstrap?,
        index: desired_instance.index,
        availability_zone: desired_instance.availability_zone
      )
    end

    def update_dns(instance_plan)
      instance = instance_plan.instance

      return unless instance_plan.dns_changed?

      @dns_manager.update_dns_record_for_instance(instance.model, instance_plan.network_settings.dns_record_info)
      @dns_manager.flush_dns_cache
    end

    # Synchronizes persistent_disks with the agent.
    # (Currently assumes that we only have 1 persistent disk.)
    # @return [void]
    def check_persistent_disk(instance)
      return if instance.model.persistent_disks.empty?
      agent_disk_cid = disk_info(instance).first

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

    def update_settings(instance)
      if instance.trusted_certs_changed?
        instance.update_trusted_certs
      end
    end

    # Returns an array of wait times distributed
    # on the [min_watch_time..max_watch_time] interval.
    #
    # Tries to respect intervals but doesn't allow an interval to
    # fall under 1 second.
    # All times are in milliseconds.
    # @param [Numeric] min_watch_time minimum time to watch the jobs
    # @param [Numeric] max_watch_time maximum time to watch the jobs
    # @param [Numeric] intervals number of intervals between polling
    #   the state of the jobs
    # @return [Array<Numeric>] watch schedule
    def watch_schedule(min_watch_time, max_watch_time, intervals = WATCH_INTERVALS)
      delta = (max_watch_time - min_watch_time).to_f
      step = [1000, delta / (intervals - 1)].max

      [min_watch_time] + ([step] * (delta / step).floor)
    end

    def get_min_watch_time(update_config)
      canary? ? update_config.min_canary_watch_time : update_config.min_update_watch_time
    end

    def get_max_watch_time(update_config)
      canary? ? update_config.max_canary_watch_time : update_config.max_update_watch_time
    end

    def canary?
      @canary
    end

    def dns_change_only?(instance_plan)
      instance_plan.changes.include?(:dns) && instance_plan.changes.size == 1
    end

    # Watch times don't include the get_state roundtrip time, so effective
    # max watch time is roughly:
    # max_watch_time + N_WATCH_INTERVALS * avg_roundtrip_time
    def wait_until_running(instance)
      min_watch_time = get_min_watch_time(instance.job.update)
      max_watch_time = get_max_watch_time(instance.job.update)
      watch_schedule(min_watch_time, max_watch_time).each do |watch_time|
        sleep_time = watch_time.to_f / 1000
        @logger.info("Waiting for #{sleep_time} seconds to check #{instance} status")
        sleep(sleep_time)
        @logger.info("Checking if #{instance} has been updated after #{sleep_time} seconds")

        @current_state = agent(instance).get_state

        if instance.state == "started"
          break if current_state["job_state"] == "running"
        elsif instance.state == "stopped"
          break if current_state["job_state"] != "running"
        end
      end
    end

    def try_to_update_in_place(instance_plan)
      instance = instance_plan.instance
      if instance_plan.recreate_deployment?
        @logger.debug("Recreate Deployment is set - instances will be recreated")
        return false
      end

      if instance_plan.needs_recreate?
        @logger.debug("Skipping update VM in place: instance will be recreated")
        return false
      end

      if instance.cloud_properties_changed?
        @logger.debug("Cloud Properties have changed. Can't update VM in place")
        return false
      end

      if instance_plan.vm_type_changed?
        @logger.debug("VM Type has changed. Can't update VM in place")
        return false
      end

      if instance_plan.stemcell_changed?
        @logger.debug("Stemcell has changed. Can't update VM in place")
        return false
      end

      if instance_plan.env_changed?
        @logger.debug("ENV has changed. Can't update VM in place")
        return false
      end

      @logger.debug('Trying to update VM settings in place')

      network_updater = NetworkUpdater.new(instance_plan, agent(instance), @cloud, @logger)
      success = network_updater.update

      unless success
        @logger.info('Failed to update networks on live vm, recreating with new network configurations')
        return false
      end

      update_settings(instance)

      true
    end

    def update_persistent_disk(instance_plan)
      instance = instance_plan.instance

      @vm_creator.attach_disks_for(instance) unless instance.disk_currently_attached?
      check_persistent_disk(instance)

      disk = nil
      return unless instance_plan.persistent_disk_changed?

      old_disk = instance.model.persistent_disk

      if instance.job.persistent_disk_type && instance.job.persistent_disk_type.disk_size > 0
        disk = create_disk(instance)
        attach_disk(instance, disk)
        mount_and_migrate_disk(instance, disk, old_disk)
      end

      instance.model.db.transaction do
        old_disk.update(:active => false) if old_disk
        disk.update(:active => true) if disk
      end

      delete_mounted_disk(instance, old_disk) if old_disk
    end

    def recreate_vm(instance_plan, new_disk_cid)
      @vm_deleter.delete_for_instance_plan(instance_plan)
      disks = [instance_plan.instance.model.persistent_disk_cid, new_disk_cid].compact
      @vm_creator.create_for_instance_plan(instance_plan, disks)

      @agent = AgentClient.with_vm(instance_plan.instance.vm.model)

      #TODO: we only render the templates again because dynamic networking may have
      #      assigned an ip address, so the state we got back from the @agent may
      #      result in a different instance.template_spec.  Ideally, we clean up the @agent interaction
      #      so that we only have to do this once.
      @job_renderer.render_job_instance(instance_plan.instance)
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

    def attach_disk(instance, disk)
      @cloud.attach_disk(instance.model.vm.cid, disk.disk_cid)
    rescue Bosh::Clouds::NoDiskSpace => e
      if e.ok_to_retry
        @logger.warn('Retrying attach disk operation after persistent disk update failed')
        recreate_vm(instance, disk.disk_cid)
        begin
          @cloud.attach_disk(instance.model.vm.cid, disk.disk_cid)
        rescue
          delete_unused_disk(disk)
          raise
        end
      else
        delete_unused_disk(disk)
        raise
      end
    end

    def mount_and_migrate_disk(instance, new_disk, old_disk)
      agent(instance).mount_disk(new_disk.disk_cid)
      agent(instance).migrate_disk(old_disk.disk_cid, new_disk.disk_cid) if old_disk
    rescue
      delete_mounted_disk(instance, new_disk)
      raise
    end

    def agent(instance)
      @agent ||= AgentClient.with_vm(instance.model.vm)
    end

    def deployment_plan(instance)
      instance.job.deployment
    end
  end
end
