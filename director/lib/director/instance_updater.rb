# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class InstanceUpdater
    include DnsHelper
    MAX_ATTACH_DISK_TRIES = 3
    UPDATE_STEPS = 7
    WATCH_INTERVALS = 10

    # @params [DeploymentPlan::Instance] instance
    def initialize(instance, event_ticker = nil)
      @cloud = Config.cloud
      @logger = Config.logger
      @ticker = event_ticker

      @instance = instance
      @job = instance.job

      @target_state = @instance.state

      @deployment_plan = @job.deployment
      @resource_pool_spec = @job.resource_pool
      @update_config = @job.update # TODO: rename

      @vm = @instance.model.vm
    end

    def instance_name
      "#{@job.name}/#{@instance.index}"
    end

    def step
      yield
      report_progress
    end

    def report_progress
      @ticker.advance(100.0 / UPDATE_STEPS) if @ticker
    end

    def update(options = {})
      changes = @instance.changes
      @logger.info("Updating instance #{@instance}, " +
                   "changes #{changes.inspect}")

      # Optimization to only update DNS if nothing else changed.
      if changes.include?(:dns) && changes.size == 1
        update_dns
        return
      end

      step { stop }

      if @target_state == "detached"
        detach_disk
        delete_vm
        @resource_pool_spec.add_idle_vm
        return
      end

      step { update_resource_pool }
      step { update_persistent_disk }
      step { update_networks }
      step { update_dns }
      step { apply_state(@instance.spec) }

      if @target_state == "started"
        begin
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
          @logger.warn("Agent start raised an exception: #{e.inspect}, " +
                       "ignoring for compatibility")
        end
      end

      min_watch_time, max_watch_time =
        options[:canary] ? canary_watch_times : update_watch_times
      current_state = nil

      # Watch times don't include the get_state roundtrip time, so effective
      # max watch time is roughly:
      # max_watch_time + N_WATCH_INTERVALS * avg_roundtrip_time
      step do
        watch_schedule(min_watch_time, max_watch_time).each do |watch_time|
          sleep_time = watch_time.to_f / 1000
          @logger.info("Waiting for #{sleep_time} seconds to " +
                       "check #{instance_name} status")
          sleep(sleep_time)
          @logger.info("Checking if #{instance_name} has been updated " +
                       "after #{sleep_time} seconds")

          current_state = agent.get_state

          if @target_state == "started"
            break if current_state["job_state"] == "running"
          elsif @target_state == "stopped"
            break if current_state["job_state"] != "running"
          end
        end
      end

      if @target_state == "started" && current_state["job_state"] != "running"
        raise AgentJobNotRunning,
              "`#{instance_name}' is not running after update"
      end

      if @target_state == "stopped" && current_state["job_state"] == "running"
        raise AgentJobNotStopped,
              "`#{instance_name}' is still running despite the stop command"
      end
    end

    def stop
      if @instance.resource_pool_changed? ||
         @instance.persistent_disk_changed? ||
         @instance.networks_changed? ||
         @target_state == "stopped" ||
         @target_state == "detached"
        drain_time = agent.drain("shutdown")
      else
        drain_time = agent.drain("update", @instance.spec)
      end

      if drain_time < 0
        drain_time = drain_time.abs
        begin
          # TODO: refactor this bit
          Config.job_cancelled?
          @logger.info("Drain - check back in #{drain_time} seconds")
          sleep(drain_time)
          drain_time = agent.drain("status")
        rescue => e
          @logger.warn("Failed to check drain status: #{e.inspect}")
          raise if e.kind_of?(Bosh::Director::TaskCancelled)
          break
        end while drain_time > 0
      else
        sleep(drain_time)
      end
      agent.stop
    end

    def detach_disk
      return unless @instance.disk_currently_attached?

      if @instance.model.persistent_disk_cid.nil?
        raise AgentUnexpectedDisk,
              "`#{instance_name}' VM has disk attached " +
              "but it's not reflected in director DB"
      end

      agent.unmount_disk(@instance.model.persistent_disk_cid)
      @cloud.detach_disk(@vm.cid, @instance.model.persistent_disk_cid)
    end

    def attach_disk
      return if @instance.model.persistent_disk_cid.nil?

      @cloud.attach_disk(@vm.cid, @instance.model.persistent_disk_cid)
      agent.mount_disk(@instance.model.persistent_disk_cid)
    end

    def delete_vm
      @cloud.delete_vm(@vm.cid)

      @instance.model.db.transaction do
        @instance.model.vm = nil
        @instance.model.save
        @vm.destroy
      end
    end

    def create_vm(new_disk_id)
      stemcell = @resource_pool_spec.stemcell
      disks = [@instance.model.persistent_disk_cid, new_disk_id].compact

      @vm = VmCreator.new.create(@deployment_plan.model, stemcell.model,
                                 @resource_pool_spec.cloud_properties,
                                 @instance.network_settings, disks,
                                 @resource_pool_spec.env)
      @instance.model.vm = @vm
      @instance.model.save

      # TODO: delete the VM if it wasn't saved
      agent.wait_until_ready
    end

    def apply_state(state)
      @vm.update(:apply_spec => state)
      agent.apply(state)
    end

    # Retrieve list of mounted disks from the agent
    # @return []Array<String>] list of disk CIDs
    def disk_info
      return @disk_list if @disk_list

      begin
        @disk_list = agent.list_disk
      rescue RuntimeError
        # old agents don't support list_disk rpc
        [@instance.persistent_disk_cid]
      end
    end

    def delete_disk(disk, vm_cid)
      disk_cid = disk.disk_cid
      # Unmount the disk only if disk is known by the agent
      if agent && disk_info.include?(disk_cid)
        agent.unmount_disk(disk_cid)
      end

      begin
        @cloud.detach_disk(vm_cid, disk_cid) if vm_cid
      rescue Bosh::Clouds::DiskNotAttached
        if disk.active
          raise CloudDiskNotAttached,
                "`#{instance_name}' VM should have persistent disk attached " +
                "but it doesn't (according to CPI)"
        end
      end

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
      @instance.dns_records.each do |record_name, ip_address|
        @logger.info("Updating DNS for: #{record_name} to #{ip_address}")
        record = Models::Dns::Record.find(:domain_id => domain.id,
                                          :name => record_name)
        if record.nil?
          record = Models::Dns::Record.new(:domain_id => domain.id,
                                           :name => record_name, :type => "A")
        end
        record.content = ip_address
        record.change_date = Time.now.to_i
        record.save

        # create/update records needed for reverse lookups
        reverse = reverse_domain(ip_address)
        rdomain = Models::Dns::Domain.find_or_create(:name => reverse,
                                                    :type => "NATIVE")
        Models::Dns::Record.find_or_create(:domain_id => rdomain.id,
                                           :name => reverse,
                                           :type =>'SOA', :content => SOA,
                                           :ttl => TTL_4H)

        Models::Dns::Record.find_or_create(:domain_id => rdomain.id,
                                           :name => reverse,
                                           :type =>'NS', :ttl => TTL_4H,
                                           :content => "ns.bosh")

        record = Models::Dns::Record.find(:domain_id => rdomain.id,
                                          :name => reverse,
                                          :type =>'PTR', :ttl => TTL_5M)
        unless record
          record = Models::Dns::Record.new(:domain_id => rdomain.id,
                                           :name => reverse,
                                           :type =>'PTR')
        end
        record.content = record_name
        record.change_date = Time.now.to_i
        record.save
      end
    end

    def update_resource_pool(new_disk_cid = nil)
      return unless @instance.resource_pool_changed? || new_disk_cid

      detach_disk
      num_retries = 0
      begin
        delete_vm
        create_vm(new_disk_cid)
        attach_disk
      rescue Bosh::Clouds::NoDiskSpace => e
        if e.ok_to_retry && num_retries < MAX_ATTACH_DISK_TRIES
          num_retries += 1
          @logger.warn("Retrying attach disk operation #{num_retries}")
          retry
        end
        @logger.warn("Giving up on attach disk operation")
        e.ok_to_retry = false
        raise CloudNotEnoughDiskSpace,
              "Not enough disk space to update `#{instance_name}'"
      end

      state = {
        "deployment" => @deployment_plan.name,
        "networks" => @instance.network_settings,
        "resource_pool" => @job.resource_pool.spec,
        "job" => @job.spec,
        "index" => @instance.index,
        "release" => @job.release.spec
      }

      if @instance.disk_size > 0
        state["persistent_disk"] = @instance.disk_size
      end

      apply_state(state)
      @instance.current_state = agent.get_state
    end

    def attach_missing_disk
      if @instance.model.persistent_disk_cid &&
         !@instance.disk_currently_attached?
        attach_disk
      end
    rescue Bosh::Clouds::NoDiskSpace => e
      update_resource_pool(@instance.model.persistent_disk_cid)
    end

    # Synchronizes persistent_disks with the agent.
    #
    # NOTE: Currently assumes that we only have 1 persistent disk.
    # @return [void]
    def check_persistent_disk
      return if @instance.model.persistent_disks.empty?
      agent_disk_cid = disk_info.first

      if agent_disk_cid != @instance.model.persistent_disk_cid
        raise AgentDiskOutOfSync,
              "`#{instance_name}' has invalid disks: agent reports " +
              "`#{agent_disk_cid}' while director record shows " +
              "`#{@instance.model.persistent_disk_cid}'"
      end

      @instance.model.persistent_disks.each do |disk|
        unless disk.active
          @logger.warn("`#{instance_name}' has inactive disk #{disk.disk_cid}")
        end
      end
    end

    def update_persistent_disk
      # CLEANUP FIXME
      # [olegs] Error cleanup should be performed AFTER logic cleanup, I can't
      # event comprehend this method.
      attach_missing_disk
      check_persistent_disk

      disk_cid = nil
      disk = nil
      return unless @instance.persistent_disk_changed?

      old_disk = @instance.model.persistent_disk

      if @job.persistent_disk > 0
        @instance.model.db.transaction do
          disk_cid = @cloud.create_disk(@job.persistent_disk, @vm.cid)
          disk =
            Models::PersistentDisk.create(:disk_cid => disk_cid,
                                          :active => false,
                                          :instance_id => @instance.model.id,
                                          :size => @job.persistent_disk)
        end

        begin
          @cloud.attach_disk(@vm.cid, disk_cid)
        rescue Bosh::Clouds::NoDiskSpace => e
          if e.ok_to_retry
            @logger.warn("Retrying attach disk operation " +
                         "after persistent disk update failed")
            # Recreate the vm
            update_resource_pool(disk_cid)
            begin
              @cloud.attach_disk(@vm.cid, disk_cid)
            rescue
              @cloud.delete_disk(disk_cid)
              disk.destroy
              raise
            end
          else
            @cloud.delete_disk(disk_cid)
            disk.destroy
            raise
          end
        end

        begin
          agent.mount_disk(disk_cid)
          agent.migrate_disk(old_disk.disk_cid, disk_cid) if old_disk
        rescue
          delete_disk(disk, @vm.cid)
          raise
        end
      end

      @instance.model.db.transaction do
        old_disk.update(:active => false) if old_disk
        disk.update(:active => true) if disk
      end

      delete_disk(old_disk, @vm.cid) if old_disk
    end

    def update_networks
      return unless @instance.networks_changed?

      network_settings = @instance.network_settings
      agent.prepare_network_change(network_settings)

      begin
        # If configure_networks can't configure the network as
        # requested, e.g. when the security groups change on AWS,
        # configure_networks() will raise an exception and we'll
        # recreate the VM to work around it
        @cloud.configure_networks(@vm.cid, network_settings)
      rescue Bosh::Clouds::NotSupported => e
        @logger.info("configure_networks not supported: #{e.message}")
        @instance.recreate = true
        update_resource_pool
        return
      end
      agent.wait_until_ready
    end

    def agent
      if @agent && @agent.id == @vm.agent_id
        @agent
      else
        if @vm.agent_id.nil?
          raise VmAgentIdMissing, "VM #{@vm.id} is missing agent id"
        end
        @agent = AgentClient.new(@vm.agent_id)
      end
    end

    def generate_agent_id
      UUIDTools::UUID.random_create.to_s
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
    def watch_schedule(min_watch_time, max_watch_time,
                       intervals = WATCH_INTERVALS)
      delta = (max_watch_time - min_watch_time).to_f
      step = [1000, delta / intervals].max

      [min_watch_time, [step] * (delta / step).floor].flatten
    end

    def canary_watch_times
      [
        @update_config.min_canary_watch_time,
        @update_config.max_canary_watch_time
      ]
    end

    def update_watch_times
      [
        @update_config.min_update_watch_time,
        @update_config.max_update_watch_time
      ]
    end
  end
end
