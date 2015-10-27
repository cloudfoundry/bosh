require 'bosh/director/rendered_job_templates_cleaner'

module Bosh::Director
  class InstanceUpdater
    WATCH_INTERVALS = 10
    MAX_RECREATE_ATTEMPTS = 3

    attr_reader :current_state

    def self.new_instance_updater(job_renderer, ip_provider)
      logger = Config.logger
      cloud = Config.cloud
      vm_deleter = VmDeleter.new(cloud, logger)
      disk_manager = DiskManager.new(cloud, logger)
      vm_creator = VmCreator.new(cloud, logger, vm_deleter, disk_manager)
      vm_recreator = VmRecreator.new(vm_creator, vm_deleter, job_renderer)
      dns_manager = DnsManager.create
      new(
        cloud,
        logger,
        ip_provider,
        App.instance.blobstores.blobstore,
        vm_deleter,
        vm_creator,
        dns_manager,
        disk_manager,
        vm_recreator
      )
    end

    def initialize(cloud, logger, ip_provider, blobstore, vm_deleter, vm_creator, dns_manager, disk_manager, vm_recreator)
      @cloud = cloud
      @logger = logger
      @blobstore = blobstore
      @vm_deleter = vm_deleter
      @vm_creator = vm_creator
      @dns_manager = dns_manager
      @disk_manager = disk_manager
      @ip_provider = ip_provider
      @current_state = {}
      @vm_recreator = vm_recreator
    end

    def update(instance_plan, options = {})
      instance = instance_plan.instance
      @logger.info("Updating instance #{instance}, changes: #{instance_plan.changes.to_a.join(', ').inspect}")

      @canary = options.fetch(:canary, false)

      # Optimization to only update DNS if nothing else changed.
      if dns_change_only?(instance_plan)
        @logger.debug('Only change is DNS configuration')
        update_dns(instance_plan)
        return
      end

      only_trusted_certs_changed = trusted_certs_change_only?(instance_plan) # figure this out before we start changing things

      Preparer.new(instance_plan, agent(instance), @logger).prepare
      stop(instance_plan)
      take_snapshot(instance)

      if instance.state == 'detached'
        @logger.info("Detaching instance #{instance}")
        @vm_deleter.delete_for_instance_plan(instance_plan)
        release_obsolete_ips(instance_plan)
        instance.update_state
        return
      end

      unless try_to_update_in_place(instance_plan)
        @logger.debug('Failed to update in place. Recreating VM')
        @vm_recreator.recreate_vm(instance_plan, nil)
      end

      release_obsolete_ips(instance_plan)

      update_dns(instance_plan)
      @disk_manager.update_persistent_disk(instance_plan, @vm_recreator)

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

    def release_obsolete_ips(instance_plan)
      instance_plan.network_plans
        .select(&:obsolete?)
        .each do |network_plan|
        reservation = network_plan.reservation
        @ip_provider.release(reservation)
      end
      instance_plan.release_obsolete_network_plans
    end

    def run_pre_start_scripts(instance)
      agent(instance).run_script("pre-start", {})
    end

    def start!(instance)
      agent(instance).start
    end

    def need_start?
      @target_state == 'started'
    end

    def dns_change_only?
      @instance.changes.include?(:dns) && @instance.changes.size == 1
    end

    def trusted_certs_change_only?(instance_plan)
      instance_plan.changes.include?(:trusted_certs) && instance_plan.changes.size == 1
    end

    def stop(instance_plan)
      instance = instance_plan.instance
      stopper = Stopper.new(instance_plan, instance.state, Config, @logger)
      stopper.stop
    end

    def take_snapshot(instance)
      Api::SnapshotManager.take_snapshot(instance.model, clean: true)
    end

    def apply_state(instance)
      instance.apply_vm_state
      RenderedJobTemplatesCleaner.new(instance.model, @blobstore, @logger).clean
    end

    def update_dns(instance_plan)
      instance = instance_plan.instance

      return unless instance_plan.dns_changed?

      @dns_manager.update_dns_record_for_instance(instance.model, instance_plan.network_settings.dns_record_info)
      @dns_manager.flush_dns_cache
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

      if instance_plan.needs_shutting_down?
        @logger.debug('Not updating VM in place. VM needs to be shutdown before it can be updated.')
        return false
      end

      if instance.cloud_properties_changed?
        @logger.debug("Cloud Properties have changed. Can't update VM in place")
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

    def agent(instance)
      AgentClient.with_vm(instance.model.vm)
    end
  end
end
