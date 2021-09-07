module Bosh::Director
  class InstanceUpdater
    class UpdateProcedure
      attr_reader :instance, :instance_plan, :options, :instance_report, :action, :context

      def initialize(instance,
                     instance_plan,
                     options,
                     blobstore,
                     needs_recreate,
                     instance_report,
                     disk_manager,
                     rendered_templates_persister,
                     vm_creator,
                     links_manager,
                     ip_provider,
                     dns_state_updater,
                     logger,
                     task)
        @instance = instance
        @instance_plan = instance_plan
        @options = options
        @blobstore = blobstore
        @needs_recreate = needs_recreate
        @instance_report = instance_report
        @disk_manager = disk_manager
        @rendered_templates_persister = rendered_templates_persister
        @vm_creator = vm_creator
        @links_manager = links_manager
        @ip_provider = ip_provider
        @dns_state_updater = dns_state_updater
        @logger = logger
        @action = calculate_action
        @context = calculate_context
        @task = task
      end

      def to_proc
        -> { perform }
      end

      def perform
        # Optimization to only update DNS if nothing else changed.
        @links_manager.bind_links_to_instance(instance)
        instance.update_variable_set

        unless full_update_required?
          if instance_plan.changes.include?(:tags)
            @logger.debug('Minimal update: VM and disk tags')
            update_vm_disk_metadata
          end

          if instance_plan.changes.include?(:dns)
            @logger.debug('Minimal update: DNS configuration')
            update_dns_if_changed
          end

          return
        end

        unless instance_plan.already_detached?
          handle_not_detached_instance_plan

          # desired state
          if instance.state == 'stopped'
            # Command issued: `bosh stop`
            update_instance
            return
          end

          handle_detached_instance_if_detached
        end

        converge_vm if instance.state != 'detached'
        update_instance
        update_dns_if_changed
        update_vm_disk_metadata

        return if instance.state == 'detached'

        @rendered_templates_persister.persist(instance_plan)
        apply_state
      end

      private

      def apply_state
        state_applier = InstanceUpdater::StateApplier.new(
          instance_plan,
          agent,
          RenderedJobTemplatesCleaner.new(instance.model, @blobstore, @logger),
          @logger,
          task: @task,
          canary: options[:canary],
        )
        state_applier.apply(instance_plan.desired_instance.instance_group.update)
      end

      def handle_not_detached_instance_plan
        # Rendered templates are persisted here, in the case where a vm is already soft stopped
        # It will update the rendered templates on the VM
        unless Config.enable_nats_delivered_templates && @needs_recreate
          @rendered_templates_persister.persist(instance_plan)
        end

        unless instance_plan.needs_shutting_down? || instance.state == 'detached'
          DeploymentPlan::Steps::PrepareInstanceStep.new(instance_plan).perform(instance_report)
        end

        # current state
        return unless instance.model.state != 'stopped'

        stop
        take_snapshot
      end

      def handle_detached_instance_if_detached
        return unless instance.state == 'detached'

        # Command issued: `bosh stop --hard`
        @logger.info("Detaching instance #{instance}")
        instance_model = instance_plan.new? ? instance_plan.instance.model : instance_plan.existing_instance
        DeploymentPlan::Steps::UnmountInstanceDisksStep.new(instance_model).perform(instance_report)
        DeploymentPlan::Steps::DetachInstanceDisksStep.new(instance_model).perform(instance_report)
        DeploymentPlan::Steps::DeleteVmStep.new(true, false, Config.enable_virtual_delete_vms).perform(instance_report)
      end

      def update_instance
        instance_plan.release_obsolete_network_plans(@ip_provider)
        instance.update_state
      end

      def update_vm_disk_metadata
        return unless instance_plan.changes.include?(:tags)
        return if instance_plan.new? || @needs_recreate
        return if instance.state == 'detached' # disks will get a metadata update when attaching again

        @logger.debug("Updating instance #{instance} VM and disk metadata with tags")
        tags = instance_plan.tags
        cloud = CloudFactory.create.get(instance.model.active_vm.cpi)
        MetadataUpdater.build.update_disk_metadata(cloud, instance.model.managed_persistent_disk, tags) if instance.model.managed_persistent_disk
        MetadataUpdater.build.update_vm_metadata(instance.model, instance.model.active_vm, tags)
      end

      def converge_vm
        recreate = @needs_recreate || (instance_plan.should_create_swap_delete? && instance_plan.instance.model.vms.count > 1)

        RecreateHandler.new(@logger, @vm_creator, @ip_provider, instance_plan, instance_report, instance).perform if recreate

        instance_report.vm = instance_plan.instance.model.active_vm
        @disk_manager.update_persistent_disk(instance_plan)

        instance.update_instance_settings(instance.model.active_vm) unless recreate
      end

      # Full update drains jobs and starts them again
      def full_update_required?
        return true if instance_plan.changes.count > 2

        # Only DNS and tag changes do not require a full update
        return false if instance_plan.changes.sort == %i[dns tags]

        return false if instance_plan.changes.first == :dns || instance_plan.changes.first == :tags

        true
      end

      def stop
        stop_intent = deleting_vm? ? :delete_vm : :keep_vm
        Stopper.stop(intent: stop_intent, instance_plan: instance_plan,
                     target_state: instance.state, logger: @logger, task: @task)
      end

      def deleting_vm?
        @needs_recreate || instance_plan.needs_shutting_down? || instance.state == 'detached' ||
          (instance_plan.should_create_swap_delete? && instance_plan.instance.model.vms.count > 1)
      end

      def calculate_action
        if restarting?
          names = {
            'started' => 'start',
            'stopped' => 'stop',
            'detached' => 'stop',
          }

          raw_name = instance_plan.instance.virtual_state
          return names[raw_name] if names.key? raw_name

          return raw_name
        end

        return 'create' if instance_plan.new?

        @needs_recreate ? 'recreate' : 'update'
      end

      def restarting?
        changes.size == 1 && %i[state restart].include?(changes.first)
      end

      def changes
        instance_plan.changes
      end

      def calculate_context
        return {} if restarting?

        context = {}
        context['az'] = instance_plan.desired_az_name if instance_plan.desired_az_name
        unless instance_plan.new?
          context['changes'] = changes.to_a unless changes.size == 1 && changes.first == :recreate
        end
        context
      end

      def update_dns_if_changed
        return unless instance_plan.dns_changed?

        @dns_state_updater.update_dns_for_instance(instance_plan, instance_plan.network_settings.dns_record_info)
      end

      def agent
        AgentClient.with_agent_id(instance.model.agent_id, instance.model.name)
      end

      def take_snapshot
        Api::SnapshotManager.take_snapshot(instance.model, clean: true)
      end
    end
  end
end
