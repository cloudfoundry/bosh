require 'bosh/director/rendered_job_templates_cleaner'

module Bosh::Director
  class InstanceUpdater
    MAX_RECREATE_ATTEMPTS = 3

    def self.new_instance_updater(ip_provider)
      logger = Config.logger
      cloud = Config.cloud
      vm_deleter = VmDeleter.new(cloud, logger)
      disk_manager = DiskManager.new(cloud, logger)
      job_renderer = JobRenderer.create
      vm_creator = VmCreator.new(cloud, logger, vm_deleter, disk_manager, job_renderer)
      vm_recreator = VmRecreator.new(vm_creator, vm_deleter)
      dns_manager = DnsManagerProvider.create
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
      @vm_recreator = vm_recreator
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
        return
      end

      unless instance_plan.currently_detached?
        Preparer.new(instance_plan, agent(instance), @logger).prepare

        stop(instance_plan)
        take_snapshot(instance)
      end

      if instance.state == 'detached'
        @logger.info("Detaching instance #{instance}")
        unless instance_plan.currently_detached?
          @disk_manager.unmount_disk_for(instance_plan)
          instance_model = instance_plan.new? ? instance_plan.instance.model : instance_plan.existing_instance
          @vm_deleter.delete_for_instance(instance_model)
        end
        release_obsolete_ips(instance_plan)
        instance.update_state
        return
      end

      recreated = false
      if needs_recreate?(instance_plan)
        @logger.debug('Failed to update in place. Recreating VM')
        @disk_manager.unmount_disk_for(instance_plan)
        @vm_recreator.recreate_vm(instance_plan, nil)
        recreated = true
      end

      release_obsolete_ips(instance_plan)

      update_dns(instance_plan)
      @disk_manager.update_persistent_disk(instance_plan, @vm_recreator)

      unless recreated
        if instance.trusted_certs_changed?
          @logger.debug('Updating trusted certs')
          instance.update_trusted_certs
        end
      end

      cleaner = RenderedJobTemplatesCleaner.new(instance.model, @blobstore, @logger)
      state_applier = InstanceUpdater::StateApplier.new(instance_plan, agent(instance), cleaner, @logger)
      state_applier.apply

      job = instance_plan.desired_instance.job
      min_watch_time = get_min_watch_time(job.update)
      max_watch_time = get_max_watch_time(job.update)
      state_applier.post_start(min_watch_time, max_watch_time)
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

    def stop(instance_plan)
      instance = instance_plan.instance
      stopper = Stopper.new(instance_plan, instance.state, Config, @logger)
      stopper.stop
    end

    def take_snapshot(instance)
      Api::SnapshotManager.take_snapshot(instance.model, clean: true)
    end

    def update_dns(instance_plan)
      instance = instance_plan.instance

      return unless instance_plan.dns_changed?

      @dns_manager.update_dns_record_for_instance(instance.model, instance_plan.network_settings.dns_record_info)
      @dns_manager.flush_dns_cache
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

    def needs_recreate?(instance_plan)
      instance = instance_plan.instance

      if instance_plan.needs_shutting_down?
        @logger.debug('VM needs to be shutdown before it can be updated.')
        return true
      end

      if instance.cloud_properties_changed?
        @logger.debug('Cloud Properties have changed. Recreating VM')
        return true
      end

      if instance_plan.networks_changed?
        @logger.debug('Networks have changed. Recreating VM')
        return true
      end

      false
    end

    def agent(instance)
      AgentClient.with_vm_credentials_and_agent_id(instance.model.credentials, instance.model.agent_id)
    end
  end
end
