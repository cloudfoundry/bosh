require 'bosh/director/rendered_job_templates_cleaner'

module Bosh::Director
  class InstanceUpdater
    MAX_RECREATE_ATTEMPTS = 3

    def self.new_instance_updater(ip_provider, job_renderer)
      logger = Config.logger
      disk_manager = DiskManager.new(logger)
      agent_broadcaster = AgentBroadcaster.new
      dns_state_updater = DirectorDnsStateUpdater.new
      vm_deleter = VmDeleter.new(logger, false, Config.enable_virtual_delete_vms)
      vm_creator = VmCreator.new(logger, vm_deleter, disk_manager, job_renderer, agent_broadcaster)
      vm_recreator = VmRecreator.new(vm_creator, vm_deleter)
      blobstore_client = App.instance.blobstores.blobstore
      rendered_templates_persistor = RenderedTemplatesPersister.new(blobstore_client, logger)
      new(
        logger,
        ip_provider,
        blobstore_client,
        dns_state_updater,
        vm_deleter,
        vm_creator,
        disk_manager,
        vm_recreator,
        rendered_templates_persistor
      )
    end

    def initialize(logger, ip_provider, blobstore, dns_state_updater, vm_deleter, vm_creator, disk_manager, vm_recreator, rendered_templates_persistor)
      @logger = logger
      @blobstore = blobstore
      @dns_state_updater = dns_state_updater
      @vm_deleter = vm_deleter
      @vm_creator = vm_creator
      @disk_manager = disk_manager
      @ip_provider = ip_provider
      @vm_recreator = vm_recreator
      @rendered_templates_persistor = rendered_templates_persistor
      @current_state = {}
    end

    def update(instance_plan, options = {})
      instance = instance_plan.instance
      action, context = get_action_and_context(instance_plan)
      parent_id = add_event(instance.deployment_model.name, action, instance.model.name, context) if instance_plan.changed?
      @logger.info("Updating instance #{instance}, changes: #{instance_plan.changes.to_a.join(', ').inspect}")

      update_procedure = lambda do
        # Optimization to only update DNS if nothing else changed.
        if dns_change_only?(instance_plan)
          @logger.debug('Only change is DNS configuration')
          update_dns(instance_plan)
          return
        end

        unless instance_plan.already_detached?
          # Rendered templates are persisted here, in the case where a vm is already soft stopped
          # It will update the rendered templates on the VM
          unless Config.enable_nats_delivered_templates && needs_recreate?(instance_plan)
            @rendered_templates_persistor.persist(instance_plan)
            instance.update_variable_set
          end

          Preparer.new(instance_plan, agent(instance), @logger).prepare

          # current state
          if instance.model.state != 'stopped'
            stop(instance_plan)
            take_snapshot(instance)
          end

          # desired state
          if instance.state == 'stopped'
            # Command issued: `bosh stop`
            instance.update_state
            return
          end
        end

        if instance.state == 'detached'
          # Command issued: `bosh stop --hard`
          @logger.info("Detaching instance #{instance}")
          unless instance_plan.already_detached?
            @disk_manager.unmount_disk_for(instance_plan)
            instance_model = instance_plan.new? ? instance_plan.instance.model : instance_plan.existing_instance
            @vm_deleter.delete_for_instance(instance_model)
          end
          release_obsolete_ips(instance_plan)
          instance.update_state
          instance.update_variable_set
          update_dns(instance_plan)
          return
        end

        recreated = false
        if needs_recreate?(instance_plan)
          @logger.debug('Failed to update in place. Recreating VM')
          @disk_manager.unmount_disk_for(instance_plan) unless instance_plan.needs_to_fix?
          tags = instance_plan.tags
          @vm_recreator.recreate_vm(instance_plan, nil, tags)
          recreated = true
        end

        release_obsolete_ips(instance_plan)

        @disk_manager.update_persistent_disk(instance_plan)
        update_dns(instance_plan)

        unless recreated
          instance.update_instance_settings
        end

        cleaner = RenderedJobTemplatesCleaner.new(instance.model, @blobstore, @logger)

        @rendered_templates_persistor.persist(instance_plan)
        instance.update_variable_set

        state_applier = InstanceUpdater::StateApplier.new(
          instance_plan,
          agent(instance),
          cleaner,
          @logger,
          canary: options[:canary]
        )
        state_applier.apply(instance_plan.desired_instance.instance_group.update)
      end

      InstanceUpdater::InstanceState.with_instance_update_and_event_creation(instance.model, parent_id, instance.deployment_model.name, action, &update_procedure)
    end

    private

    def add_event(deployment_name, action, instance_name = nil, context = nil, parent_id = nil, error = nil)
      event = Config.current_job.event_manager.create_event(
        {
          parent_id: parent_id,
          user: Config.current_job.username,
          action: action,
          object_type: 'instance',
          object_name: instance_name,
          task: Config.current_job.task_id,
          deployment: deployment_name,
          instance: instance_name,
          error: error,
          context: context ? context : {}
        })
      event.id
    end

    def get_action_and_context(instance_plan)
      changes = instance_plan.changes
      context = {}
      if changes.size == 1 && [:state, :restart].include?(changes.first)
        action = case instance_plan.instance.virtual_state
                   when 'started'
                     'start'
                   when 'stopped'
                     'stop'
                   when 'detached'
                     'stop'
                   else
                     instance_plan.instance.virtual_state
                 end
      else
        context['az'] = instance_plan.desired_az_name if instance_plan.desired_az_name
        if instance_plan.new?
          action = 'create'
        else
          context['changes'] = changes.to_a unless changes.size == 1 && changes.first == :recreate
          action = needs_recreate?(instance_plan) ? 'recreate' : 'update'
        end
      end
      return action, context
    end

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
      return unless instance_plan.dns_changed?

      @dns_state_updater.update_dns_for_instance(instance_plan.instance.model, instance_plan.network_settings.dns_record_info)
    end

    def dns_change_only?(instance_plan)
      instance_plan.changes.include?(:dns) && instance_plan.changes.size == 1
    end

    def needs_recreate?(instance_plan)
      if instance_plan.needs_shutting_down?
        @logger.debug('VM needs to be shutdown before it can be updated.')
        return true
      end

      false
    end

    def agent(instance)
      AgentClient.with_vm_credentials_and_agent_id(instance.model.credentials, instance.model.agent_id)
    end
  end
end
