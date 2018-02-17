require 'bosh/director/rendered_job_templates_cleaner'

module Bosh::Director
  class InstanceUpdater
    MAX_RECREATE_ATTEMPTS = 3

    def self.new_instance_updater(ip_provider, template_blob_cache, dns_encoder)
      logger = Config.logger
      disk_manager = DiskManager.new(logger)
      agent_broadcaster = AgentBroadcaster.new
      vm_deleter = VmDeleter.new(false, Config.enable_virtual_delete_vms)
      dns_state_updater = DirectorDnsStateUpdater.new(dns_encoder)
      vm_creator = VmCreator.new(logger, template_blob_cache, dns_encoder, agent_broadcaster)
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
        rendered_templates_persistor,
      )
    end

    def initialize(logger,
                   ip_provider,
                   blobstore,
                   dns_state_updater,
                   vm_deleter,
                   vm_creator,
                   disk_manager,
                   rendered_templates_persistor)
      @logger = logger
      @blobstore = blobstore
      @dns_state_updater = dns_state_updater
      @vm_deleter = vm_deleter
      @vm_creator = vm_creator
      @disk_manager = disk_manager
      @ip_provider = ip_provider
      @rendered_templates_persistor = rendered_templates_persistor
      @current_state = {}
    end

    def update(instance_plan, options = {})
      instance = instance_plan.instance
      instance_report = DeploymentPlan::Stages::Report.new.tap { |r| r.vm = instance.model.active_vm }
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

          unless instance_plan.needs_shutting_down? || instance.state == 'detached'
            DeploymentPlan::Steps::PrepareInstanceStep.new(instance_plan).perform(instance_report)
          end

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
            instance_model = instance_plan.new? ? instance_plan.instance.model : instance_plan.existing_instance
            DeploymentPlan::Steps::UnmountInstanceDisksStep.new(instance_model).perform(instance_report)
            DeploymentPlan::Steps::DeleteVmStep.new(true, false, Config.enable_virtual_delete_vms)
                                               .perform(instance_report)
          end
          instance_plan.release_obsolete_network_plans(@ip_provider)
          instance.update_state
          instance.update_variable_set
          update_dns(instance_plan)
          return
        end

        recreated = false

        instance_model = instance_plan.instance.model

        if needs_recreate?(instance_plan)
          new_vm = instance_model.most_recent_inactive_vm || instance_model.active_vm

          @logger.debug('Failed to update in place. Recreating VM')
          unless instance_plan.needs_to_fix?
            DeploymentPlan::Steps::UnmountInstanceDisksStep.new(instance_model).perform(instance_report)
            DeploymentPlan::Steps::DetachInstanceDisksStep.new(instance_model).perform(instance_report)
          end
          tags = instance_plan.tags

          disks = instance_model.active_persistent_disks.collection
                                .map(&:model)
                                .map(&:disk_cid).compact

          if instance_plan.should_hot_swap?
            old_vm = instance_report.vm
            instance_report.vm = new_vm
            DeploymentPlan::Steps::ElectActiveVmStep.new.perform(instance_report)
            DeploymentPlan::Steps::OrphanVmStep.new(old_vm).perform(instance_report)
          else
            DeploymentPlan::Steps::DeleteVmStep.new(true, false, Config.enable_virtual_delete_vms)
                                               .perform(instance_report)
            @vm_creator.create_for_instance_plan(instance_plan, @ip_provider, disks, tags)
          end

          recreated = true
        end

        instance_report.vm = instance_model.active_vm

        if instance_plan.should_hot_swap?
          if instance_plan.needs_disk?
            DeploymentPlan::Steps::AttachInstanceDisksStep.new(instance_model, instance_plan.tags).perform(instance_report)
            DeploymentPlan::Steps::MountInstanceDisksStep.new(instance_model).perform(instance_report)
          end
        else
          instance_plan.release_obsolete_network_plans(@ip_provider)
        end

        update_dns(instance_plan)
        @disk_manager.update_persistent_disk(instance_plan)

        instance.update_instance_settings unless recreated

        cleaner = RenderedJobTemplatesCleaner.new(instance.model, @blobstore, @logger)

        @rendered_templates_persistor.persist(instance_plan)
        instance.update_variable_set

        state_applier = InstanceUpdater::StateApplier.new(
          instance_plan,
          agent(instance),
          cleaner,
          @logger,
          canary: options[:canary],
        )
        state_applier.apply(instance_plan.desired_instance.instance_group.update)
      end

      InstanceUpdater::InstanceState
        .with_instance_update_and_event_creation(
          instance.model,
          parent_id,
          instance.deployment_model.name,
          action,
          &update_procedure
        )
    end

    private

    def add_event(deployment_name,
                  action, instance_name = nil,
                  context = nil,
                  parent_id = nil,
                  error = nil)
      event = Config.current_job.event_manager.create_event(
        parent_id: parent_id,
        user: Config.current_job.username,
        action: action,
        object_type: 'instance',
        object_name: instance_name,
        task: Config.current_job.task_id,
        deployment: deployment_name,
        instance: instance_name,
        error: error,
        context: context ? context : {},
      )
      event.id
    end

    def get_action_and_context(instance_plan)
      changes = instance_plan.changes
      context = {}
      if changes.size == 1 && %i[state restart].include?(changes.first)
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
      [action, context]
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
      AgentClient.with_agent_id(instance.model.agent_id)
    end
  end
end
