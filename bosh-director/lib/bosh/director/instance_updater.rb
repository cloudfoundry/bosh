require 'bosh/director/rendered_job_templates_cleaner'

module Bosh::Director
  class InstanceUpdater
    include DnsHelper

    WATCH_INTERVALS = 10

    attr_reader :current_state

    # @params [DeploymentPlan::Instance] instance
    def initialize(instance, event_log_task, job_renderer)
      @instance = instance
      @event_log_task = event_log_task
      @job_renderer = job_renderer

      @cloud = Config.cloud
      @logger = Config.logger
      @blobstore = App.instance.blobstores.blobstore

      @job = instance.job
      @target_state = @instance.state

      @deployment_plan = @job.deployment
      @resource_pool = @job.resource_pool
      @update_config = @job.update

      @vm = @instance.model.vm

      @current_state = {}

      @agent = AgentClient.with_defaults(@vm.agent_id)
    end

    def report_progress(num_steps)
      @event_log_task.advance(100.0 / num_steps)
    end

    def update_steps(options = {})
      steps = []
      @canary = options.fetch(:canary, false)

      # Optimization to only update DNS if nothing else changed.
      if dns_change_only?
        steps << proc { update_dns }
        return steps
      end

      steps << proc { Preparer.new(@instance, agent, @logger).prepare }
      steps << proc { stop }
      steps << proc { take_snapshot }

      if @target_state == "detached"
        steps << proc { vm_updater.detach }
        return steps
      end

      steps << proc { recreate_vm(nil) }
      steps << proc { update_networks }
      steps << proc { update_dns }
      steps << proc { update_persistent_disk }
      steps << proc { update_settings }

      if !trusted_certs_change_only?
        steps << proc {
          VmMetadataUpdater.build.update(@vm, {})
          apply_state(@instance.spec)
          RenderedJobTemplatesCleaner.new(@instance.model, @blobstore, @logger).clean
        }
      end

      if need_start?
        steps << proc { run_pre_start_scripts }
        steps << proc { start! }
      end

      steps << proc { wait_until_running }

      steps
    end

    def update(options = {})
      steps = update_steps(options)

      @logger.info("Updating instance #{@instance}, changes: #{@instance.changes.to_a.join(', ')}")

      steps.each do |step|
        step.call
        report_progress(steps.length)
      end

      if @target_state == "started" && current_state["job_state"] != "running"
        raise AgentJobNotRunning, "`#{@instance}' is not running after update"
      end

      if @target_state == "stopped" && current_state["job_state"] == "running"
        raise AgentJobNotStopped, "`#{@instance}' is still running despite the stop command"
      end
    end

    # Watch times don't include the get_state roundtrip time, so effective
    # max watch time is roughly:
    # max_watch_time + N_WATCH_INTERVALS * avg_roundtrip_time
    def wait_until_running
      watch_schedule(min_watch_time, max_watch_time).each do |watch_time|
        sleep_time = watch_time.to_f / 1000
        @logger.info("Waiting for #{sleep_time} seconds to check #{@instance} status")
        sleep(sleep_time)
        @logger.info("Checking if #{@instance} has been updated after #{sleep_time} seconds")

        @current_state = agent.get_state

        if @target_state == "started"
          break if current_state["job_state"] == "running"
        elsif @target_state == "stopped"
          break if current_state["job_state"] != "running"
        end
      end
    end

    def run_pre_start_scripts
      @agent.run_script("pre-start", {})
    end

    def start!
      agent.start
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
      @logger.warn("Agent start raised an exception: #{e.inspect}, ignoring for compatibility")
    end

    def need_start?
      @target_state == 'started'
    end

    def dns_change_only?
      @instance.changes.include?(:dns) && @instance.changes.size == 1
    end

    def trusted_certs_change_only?
      @instance.changes.include?(:trusted_certs) && @instance.changes.size == 1
    end

    def stop
      skip_drain = @deployment_plan.skip_drain_for_job?(@job.name)
      stopper = Stopper.new(@instance, agent, @target_state, skip_drain, Config, @logger)
      stopper.stop
    end

    def take_snapshot
      Api::SnapshotManager.take_snapshot(@instance.model, clean: true)
    end

    def delete_snapshots(disk)
      Api::SnapshotManager.delete_snapshots(disk.snapshots)
    end

    def apply_state(state)
      @vm.update(:apply_spec => state)
      agent.apply(state)
    end

    # Retrieve list of mounted disks from the agent
    # @return [Array<String>] list of disk CIDs
    def disk_info
      return @disk_list if @disk_list

      begin
        @disk_list = agent.list_disk
      rescue RuntimeError
        # old agents don't support list_disk rpc
        [@instance.persistent_disk_cid]
      end
    end

    def delete_unused_disk(disk)
      @cloud.delete_disk(disk.disk_cid)
      disk.destroy
    end

    def delete_mounted_disk(disk)
      disk_cid = disk.disk_cid
      vm_cid = @vm.cid

      # Unmount the disk only if disk is known by the agent
      if agent && disk_info.include?(disk_cid)
        agent.unmount_disk(disk_cid)
      end

      begin
        @cloud.detach_disk(vm_cid, disk_cid) if vm_cid
      rescue Bosh::Clouds::DiskNotAttached
        if disk.active
          raise CloudDiskNotAttached,
                "`#{@instance}' VM should have persistent disk attached " +
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

    def update_dns
      return unless @instance.dns_changed?

      domain = @deployment_plan.dns_domain
      @instance.dns_record_info.each do |record_name, ip_address|
        @logger.info("Updating DNS for: #{record_name} to #{ip_address}")
        update_dns_a_record(domain, record_name, ip_address)
        update_dns_ptr_record(record_name, ip_address)
      end
      flush_dns_cache
    end

    def recreate_vm(new_disk_cid)
      @vm, @agent = vm_updater.update(new_disk_cid)
    end

    # Synchronizes persistent_disks with the agent.
    # (Currently assumes that we only have 1 persistent disk.)
    # @return [void]
    def check_persistent_disk
      return if @instance.model.persistent_disks.empty?
      agent_disk_cid = disk_info.first

      if agent_disk_cid != @instance.model.persistent_disk_cid
        raise AgentDiskOutOfSync,
              "`#{@instance}' has invalid disks: agent reports " +
                  "`#{agent_disk_cid}' while director record shows " +
                  "`#{@instance.model.persistent_disk_cid}'"
      end

      @instance.model.persistent_disks.each do |disk|
        unless disk.active
          @logger.warn("`#{@instance}' has inactive disk #{disk.disk_cid}")
        end
      end
    end

    def update_persistent_disk
      vm_updater.attach_missing_disk
      check_persistent_disk

      disk = nil
      return unless @instance.persistent_disk_changed?

      old_disk = @instance.model.persistent_disk

      if @job.persistent_disk_pool && @job.persistent_disk_pool.disk_size > 0
        disk = create_disk
        attach_disk(disk)
        mount_and_migrate_disk(disk, old_disk)
      end

      @instance.model.db.transaction do
        old_disk.update(:active => false) if old_disk
        disk.update(:active => true) if disk
      end

      delete_mounted_disk(old_disk) if old_disk
    end

    def update_networks
      network_updater = NetworkUpdater.new(@instance, @vm, agent, vm_updater, @cloud, @logger)
      @vm, @agent = network_updater.update
    end

    def update_settings
      if @instance.trusted_certs_changed?
        @agent.update_settings(Config.trusted_certs)
        @vm.update(:trusted_certs_sha1 => Digest::SHA1.hexdigest(Config.trusted_certs))
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

    def min_watch_time
      canary? ? @update_config.min_canary_watch_time : @update_config.min_update_watch_time
    end

    def max_watch_time
      canary? ? @update_config.max_canary_watch_time : @update_config.max_update_watch_time
    end

    def canary?
      @canary
    end

    attr_reader :agent

    def vm_updater
      # Do not memoize to avoid caching same VM and agent
      # which could be replaced after updating a VM
      VmUpdater.new(@instance, @vm, agent, @job_renderer, @cloud, 3, @logger)
    end

    private

    def create_disk
      disk_size = @job.persistent_disk_pool.disk_size
      cloud_properties = @job.persistent_disk_pool.cloud_properties

      disk = nil
      @instance.model.db.transaction do
        disk_cid = @cloud.create_disk(disk_size, cloud_properties, @vm.cid)
        disk = Models::PersistentDisk.create(
          disk_cid: disk_cid,
          active: false,
          instance_id: @instance.model.id,
          size: disk_size,
          cloud_properties: cloud_properties,
        )
      end
      disk
    end

    def attach_disk(disk)
      @cloud.attach_disk(@vm.cid, disk.disk_cid)
    rescue Bosh::Clouds::NoDiskSpace => e
      if e.ok_to_retry
        @logger.warn('Retrying attach disk operation after persistent disk update failed')
        recreate_vm(disk.disk_cid)
        begin
          @cloud.attach_disk(@vm.cid, disk.disk_cid)
        rescue
          delete_unused_disk(disk)
          raise
        end
      else
        delete_unused_disk(disk)
        raise
      end
    end

    def mount_and_migrate_disk(new_disk, old_disk)
      agent.mount_disk(new_disk.disk_cid)
      agent.migrate_disk(old_disk.disk_cid, new_disk.disk_cid) if old_disk
    rescue
      delete_mounted_disk(new_disk)
      raise
    end
  end
end
