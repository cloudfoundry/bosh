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
                     rendered_templates_persistor,
                     vm_creator,
                     links_manager,
                     ip_provider,
                     dns_state_updater,
                     logger)
        @instance = instance
        @instance_plan = instance_plan
        @options = options
        @blobstore = blobstore
        @needs_recreate = needs_recreate
        @instance_report = instance_report
        @disk_manager = disk_manager
        @rendered_templates_persistor = rendered_templates_persistor
        @vm_creator = vm_creator
        @links_manager = links_manager
        @ip_provider = ip_provider
        @dns_state_updater = dns_state_updater
        @logger = logger
        @action = calculate_action
        @context = calculate_context
      end

      def to_proc
        -> { perform }
      end

      def perform
        @instance_variable_and_links_updated = false

        # Optimization to only update DNS if nothing else changed.
        if dns_change_only?
          @logger.debug('Only change is DNS configuration')
          update_dns
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

          handle_detached_instance
        end

        converge_vm if instance.state != 'detached'
        update_instance
        update_dns

        return if instance.state == 'detached'

        @rendered_templates_persistor.persist(instance_plan)
        apply_state
      end

      private

      def needs_recreate?
        @needs_recreate
      end

      def apply_state
        state_applier = InstanceUpdater::StateApplier.new(
          instance_plan,
          agent,
          RenderedJobTemplatesCleaner.new(instance.model, @blobstore, @logger),
          @logger,
          canary: options[:canary],
        )
        state_applier.apply(instance_plan.desired_instance.instance_group.update)
      end

      def handle_not_detached_instance_plan
        # Rendered templates are persisted here, in the case where a vm is already soft stopped
        # It will update the rendered templates on the VM
        unless Config.enable_nats_delivered_templates && needs_recreate?
          @rendered_templates_persistor.persist(instance_plan)
          @links_manager.bind_links_to_instance(instance)
          instance.update_variable_set
          @instance_variable_and_links_updated = true
        end

        unless instance_plan.needs_shutting_down? || instance.state == 'detached'
          DeploymentPlan::Steps::PrepareInstanceStep.new(instance_plan).perform(instance_report)
        end

        # current state
        if instance.model.state != 'stopped'
          stop
          take_snapshot
        end
      end

      def handle_detached_instance
        return if instance.state != 'detached'

        # Command issued: `bosh stop --hard`
        @logger.info("Detaching instance #{instance}")
        instance_model = instance_plan.new? ? instance_plan.instance.model : instance_plan.existing_instance
        DeploymentPlan::Steps::UnmountInstanceDisksStep.new(instance_model).perform(instance_report)
        DeploymentPlan::Steps::DeleteVmStep.new(true, false, Config.enable_virtual_delete_vms).perform(instance_report)
      end

      def update_instance
        instance_plan.release_obsolete_network_plans(@ip_provider)
        instance.update_state
        return if @instance_variable_and_links_updated
        @links_manager.bind_links_to_instance(instance)
        instance.update_variable_set
      end

      def converge_vm
        recreate = needs_recreate? || (instance_plan.should_create_swap_delete? && instance_plan.instance.model.vms.count > 1)

        RecreateHandler.new(@logger, @vm_creator, @ip_provider, instance_plan, instance_report, instance).perform if recreate

        instance_report.vm = instance_plan.instance.model.active_vm
        @disk_manager.update_persistent_disk(instance_plan)

        instance.update_instance_settings unless recreate
      end

      def dns_change_only?
        instance_plan.changes.include?(:dns) && instance_plan.changes.size == 1
      end

      def stop
        instance = instance_plan.instance
        stopper = Stopper.new(instance_plan, instance.state, Config, @logger)
        stopper.stop
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

        needs_recreate? ? 'recreate' : 'update'
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

      def update_dns
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
