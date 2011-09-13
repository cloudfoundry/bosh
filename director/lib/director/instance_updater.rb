module Bosh::Director
  class InstanceUpdater
    MAX_ATTACH_DISK_TRIES = 3
    N_UPDATE_STEPS = 6
    N_WATCH_INTERVALS = 10

    # @params instance_spec Bosh::DeploymentPlan::InstanceSpec
    def initialize(instance_spec, event_ticker = nil)
      @cloud  = Config.cloud
      @logger = Config.logger
      @ticker = event_ticker

      @instance_spec = instance_spec
      @job_spec      = instance_spec.job

      @instance     = @instance_spec.instance
      @target_state = @instance_spec.state

      @deployment_plan    = @job_spec.deployment
      @resource_pool_spec = @job_spec.resource_pool
      @update_config      = @job_spec.update

      @vm = @instance.vm
    end

    def instance_name
      "#{@job_spec.name}/#{@instance_spec.index}"
    end

    def step
      yield
      report_progress
    end

    def report_progress
      @ticker.advance(100.0 / N_UPDATE_STEPS) if @ticker
    end

    def update(options = {})
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
      step { apply_state(@instance_spec.spec) }

      if @target_state == "started"
        begin
          agent.start
        rescue RuntimeError => e
          # FIXME: this is somewhat ghetto: we don't have a good way to negotiate
          # on Bosh protocol between director and agent (yet), so updating from
          # agent version that doesn't support 'start' RPC to the one that does might
          # is hard. Right now we decided to just swallow the exception.
          # This needs to be removed in one of the following cases:
          # 1. Bosh protocol handshake gets implemented
          # 2. All agents updated to support 'start' RPC
          #    and we no longer care about backward compatibility.
          @logger.warn("Agent start raised an exception: #{e.inspect}, ignoring for compatibility")
        end
      end

      min_watch_time, max_watch_time = options[:canary] ? canary_watch_times : update_watch_times
      current_state = nil

      # Watch times don't include the get_state roundtrip time, so effective max watch time
      # is roughly max_watch_time + N_WATCH_INTERVALS * avg_roundtrip_time
      step do
        watch_schedule(min_watch_time, max_watch_time).each do |watch_time|
          sleep_time = watch_time.to_f / 1000
          @logger.info("Waiting for #{sleep_time} seconds to check #{self.instance_name} status")
          sleep(sleep_time)
          @logger.info("Checking if #{self.instance_name} has been updated after #{sleep_time} seconds")

          current_state = agent.get_state

          if @target_state == "started"
            break if current_state["job_state"] == "running"
          elsif @target_state == "stopped"
            break if current_state["job_state"] != "running"
          end
        end
      end

      if @target_state == "started" && current_state["job_state"] != "running"
        raise "updated instance not healthy"
      elsif @target_state == "stopped" && current_state["job_state"] == "running"
        raise "instance is still running despite the stop command"
      end
    end

    def stop
      if @instance_spec.resource_pool_changed? || @instance_spec.persistent_disk_changed? ||
          @instance_spec.networks_changed? || @target_state == "stopped" || @target_state == "detached"
        drain_time = agent.drain("shutdown")
      else
        drain_time = agent.drain("update", @instance_spec.spec)
      end
      sleep(drain_time)
      agent.stop
    end

    def detach_disk
      return unless @instance_spec.disk_currently_attached?

      if @instance.disk_cid.nil?
        raise "Error while detaching disk: unknown disk attached to instance"
      end

      unmount_disk(agent, @instance.disk_cid)
      @cloud.detach_disk(@vm.cid, @instance.disk_cid)
    end

    def attach_disk
      return if @instance.disk_cid.nil?

      @cloud.attach_disk(@vm.cid, @instance.disk_cid)
      mount_disk(agent, @instance.disk_cid)
    end

    def delete_vm
      @cloud.delete_vm(@vm.cid)

      @instance.db.transaction do
        @instance.vm = nil
        @instance.save
        @vm.destroy
      end
    end

    def create_vm(new_disk_id)
      stemcell = @resource_pool_spec.stemcell.stemcell
      agent_id = generate_agent_id

      @vm = Models::Vm.new
      @vm.deployment = @deployment_plan.deployment
      @vm.agent_id = agent_id
      @vm.save

      disks = [@instance.disk_cid, new_disk_id].compact

      @vm.cid = @cloud.create_vm(agent_id, stemcell.cid, @resource_pool_spec.cloud_properties,
                                 @instance_spec.network_settings, disks, @resource_pool_spec.env)

      @instance.db.transaction do
        @vm.save
        @instance.vm = @vm
        @instance.save
      end

      # TODO: delete the VM if it wasn't saved
      agent.wait_until_ready
    end

    def apply_state(state)
      task = agent.apply(state)
      while task["state"] == "running"
        sleep(1.0)
        task = agent.get_task(task["agent_task_id"])
      end
    end

    def mount_disk(agent, disk_cid)
      task = agent.mount_disk(disk_cid)
      while task["state"] == "running"
        sleep(1.0)
        task = agent.get_task(task["agent_task_id"])
      end
    end

    def unmount_disk(agent, disk_cid)
      task = agent.unmount_disk(disk_cid)
      while task["state"] == "running"
        sleep(1.0)
        task = agent.get_task(task["agent_task_id"])
      end
    end

    def migrate_disk(agent, src_disk_cid, dst_disk_cid)
      task = agent.migrate_disk(src_disk_cid, dst_disk_cid)
      while task["state"] == "running"
        sleep(1.0)
        task = agent.get_task(task["agent_task_id"])
      end
    end

    def delete_disk(agent, vm_cid, disk_cid)
      unmount_disk(agent, disk_cid) rescue nil if agent
      @cloud.detach_disk(vm_cid, disk_cid) rescue nil if vm_cid
      @cloud.delete_disk(disk_cid)
    end

    def update_resource_pool(new_disk_cid = nil)
      return unless @instance_spec.resource_pool_changed? || new_disk_cid

      detach_disk
      num_retries = 0
      begin
        delete_vm
        create_vm(new_disk_cid)
        attach_disk
      rescue NoDiskSpace => e
        if e.ok_to_retry && num_retries < MAX_ATTACH_DISK_TRIES
          num_retries += 1
          @logger.warn("Retrying attach disk operation #{num_retries}")
          retry
        end
        @logger.warn("Giving up on attach disk operation")
        e.ok_to_retry = false
        raise
      end

      state = {
        "deployment" => @deployment_plan.name,
        "networks" => @instance_spec.network_settings,
        "resource_pool" => @job_spec.resource_pool.spec,
      }

      if @instance_spec.disk_size > 0
        state["persistent_disk"] = @instance_spec.disk_size
      end

      apply_state(state)
      @instance_spec.current_state = agent.get_state
    end

    def attach_missing_disk
      if @instance.disk_cid && !@instance_spec.disk_currently_attached?
        attach_disk
      end
    rescue NoDiskSpace => e
      update_resource_pool(@instance.disk_cid)
    end

    def update_persistent_disk
      attach_missing_disk

      return unless @instance_spec.persistent_disk_changed?
      old_disk_cid = @instance.disk_cid

      if @job_spec.persistent_disk > 0
        disk_cid = @cloud.create_disk(@job_spec.persistent_disk, @vm.cid)
        begin
          @cloud.attach_disk(@vm.cid, disk_cid)
        rescue NoDiskSpace => e
          if e.ok_to_retry
            @logger.warn("Retrying attach disk operation after persistent disk update failed")
            # Recreate the vm
            update_resource_pool(disk_cid)
            begin
              @cloud.attach_disk(@vm.cid, disk_cid)
            rescue
              # Cleanup disk model entry
              @cloud.delete_disk(disk_cid)
              raise
            end
          else
            # Cleanup disk model entry
            @cloud.delete_disk(disk_cid)
            raise
          end
        end

        begin
          mount_disk(agent, disk_cid)
          migrate_disk(agent, old_disk_cid, disk_cid) if old_disk_cid
        rescue
          delete_disk(agent, nil, disk_cid) rescue nil
          raise
        end
      end

      @instance.disk_cid = disk_cid
      @instance.disk_size = @job_spec.persistent_disk
      @instance.save
      delete_disk(agent, @vm.cid, old_disk_cid) if old_disk_cid
    end

    def update_networks
      return unless @instance_spec.networks_changed?

      network_settings = @instance_spec.network_settings
      agent.prepare_network_change(network_settings)
      @cloud.configure_networks(@vm.cid, network_settings)
      agent.wait_until_ready
    end

    def agent
      if @agent && @agent.id == @vm.agent_id
        @agent
      else
        raise "agent id required to create an agent client" if @vm.agent_id.nil?
        @agent = AgentClient.new(@vm.agent_id)
      end
    end

    def generate_agent_id
      UUIDTools::UUID.random_create.to_s
    end

    # Returns an array of wait times distributed
    # on the [min_watch_time..max_watch_time] interval.
    # Tries to respect n_intervals but doesn't
    # allow an interval to fall under 1 second.
    # All times are in milliseconds.
    def watch_schedule(min_watch_time, max_watch_time, n_intervals = N_WATCH_INTERVALS)
      delta = (max_watch_time - min_watch_time).to_f
      step = [ 1000, delta / n_intervals ].max

      [ min_watch_time, [step] * (delta / step).floor ].flatten
    end

    def canary_watch_times
      [ @update_config.min_canary_watch_time, @update_config.max_canary_watch_time ]
    end

    def update_watch_times
      [ @update_config.min_update_watch_time, @update_config.max_update_watch_time ]
    end

  end
end
