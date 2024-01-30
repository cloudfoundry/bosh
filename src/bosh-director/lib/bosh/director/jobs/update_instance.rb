module Bosh::Director
  module Jobs
    class UpdateInstance < BaseJob
      include LockHelper

      AGENT_START_TIMEOUT = 90

      @queue = :normal

      def initialize(deployment_name, instance_id, action, options = {})
        @deployment_name = deployment_name
        @instance_id = instance_id
        @action = action
        @options = options
        @logger = Config.logger
      end

      def self.job_type
        :update_instance
      end

      def perform
        with_deployment_lock(@deployment_name) do
          instance_model = Models::Instance.find(id: @instance_id)
          raise InstanceNotFound if instance_model.nil?
          raise InstanceNotFound if instance_model.deployment.name != @deployment_name

          deployment_plan = DeploymentPlan::PlannerFactory.create(@logger)
            .create_from_model(instance_model.deployment)

          hm_label = label
          instance_group = deployment_plan.instance_groups.find { |ig| ig.name == instance_model.job }
          if instance_group.errand?
            raise InstanceGroupInvalidLifecycleError,
                  "Isolated #{label} can not be run on instances of type errand. Try the bosh run-errand command."
          end

          if instance_model.ignore
            raise DeploymentIgnoredInstancesModification,
                  "You are trying to change the state of the ignored instance '#{instance_model.name}'." \
                  'This operation is not allowed. You need to unignore it first.'
          end

          begin_stage("Updating instance #{instance_model}")

          notifier = DeploymentPlan::Notifier.new(@deployment_name, Config.nats_rpc, @logger)
          notifier.send_begin_instance_event(instance_model.name, hm_label)
          begin
            case @action
            when 'stop'
              stop_instance(instance_model, deployment_plan)
            when 'start'
              start_instance(instance_model, deployment_plan)
            when 'restart'
              restart_instance(instance_model, hm_label, deployment_plan)
            end
          rescue StandardError => e
            raise e
          ensure
            notifier.send_end_instance_event(instance_model.name, hm_label)
          end

          instance_model.name
        end
      end

      private

      def label
        case @action
        when 'stop'
          label = @action
        when 'start'
          label = @action
        when 'restart'
          label = @options['hard'] ? 'recreate' : 'restart'
        end

        label
      end

      def stop_instance(instance_model, deployment_plan)
        return if instance_model.stopped? && !@options['hard'] # stopped already, and we didn't pass in hard to change it
        return if instance_model.detached? # implies stopped

        instance_plan = DeploymentPlan::InstancePlanFromDB.create_from_instance_model(
          instance_model,
          deployment_plan,
          'stopped',
          @logger,
          @options,
        )

        track_and_log('Stopping instance') do
          stop(instance_model, instance_plan)
        end

        if @options['hard']
          track_and_log('Deleting VM') do
            detach_instance(instance_model, instance_plan)
          end
        end
      end

      def start_instance(instance_model, deployment_plan)
        instance_plan = DeploymentPlan::InstancePlanFromDB.create_from_instance_model(
          instance_model,
          deployment_plan,
          'started',
          @logger,
        )

        if instance_model.vm_cid.nil?
          track_and_log('Creating VM') do
            create_vm(instance_plan, deployment_plan, instance_model)
          end
        end

        return unless instance_plan.state_changed?

        track_and_log('Starting instance') do
          start(instance_plan, instance_model)
        end
      end

      def restart_instance(instance_model, label, deployment_plan)
        parent_event_id = add_event(label, instance_model)

        stop_instance(instance_model, deployment_plan)
        start_instance(instance_model, deployment_plan)
      rescue StandardError => e
        raise e
      ensure
        add_event(label, instance_model, parent_event_id, e)
      end

      def detach_instance(instance_model, instance_plan)
        task_checkpoint

        instance_report = DeploymentPlan::Stages::Report.new.tap { |r| r.vm = instance_model.active_vm }
        unless instance_plan.unresponsive_agent?
          DeploymentPlan::Steps::UnmountInstanceDisksStep.new(instance_model).perform(instance_report)
          DeploymentPlan::Steps::DetachInstanceDisksStep.new(instance_model).perform(instance_report)
        end

        DeploymentPlan::Steps::DeleteVmStep.new(true, false, Config.enable_virtual_delete_vms).perform(instance_report)
        @logger.debug("Setting instance #{@instance_id} state to detached")
        instance_model.update(state: 'detached')
      end

      def stop(instance_model, instance_plan)
        task_checkpoint

        intent = @options['hard'] ? :delete_vm : :keep_vm
        target_state = @options['hard'] ? 'detached' : 'stopped'
        parent_event = add_event('stop', instance_model)

        Stopper.stop(intent: intent, instance_plan: instance_plan, target_state: target_state, logger: @logger)

        Api::SnapshotManager.take_snapshot(instance_model, clean: true)
        @logger.debug("Setting instance #{@instance_id} state to stopped")
        instance_model.update(state: 'stopped')
      rescue StandardError => e
        raise e
      ensure
        add_event('stop', instance_model, parent_event, e) if parent_event
      end

      def start(instance_plan, instance_model)
        task_checkpoint

        blobstore_client = App.instance.blobstores.blobstore
        agent = AgentClient.with_agent_id(instance_model.agent_id, instance_model.name, timeout: AGENT_START_TIMEOUT)

        parent_event = add_event('start', instance_model)

        templates_persister = RenderedTemplatesPersister.new(blobstore_client, @logger)
        templates_persister.persist(instance_plan)
        cleaner = RenderedJobTemplatesCleaner.new(instance_model, blobstore_client, @logger)

        instance_plan.instance.update_state # set instance model to started as soon as we begin the start process
        instance_model.update(update_completed: false)
        InstanceUpdater::StateApplier.new(instance_plan, agent, cleaner, @logger, {}).apply(
          instance_plan.desired_instance.instance_group.update,
          true,
        )
        instance_model.update(update_completed: true)
      rescue StandardError => e
        raise e
      ensure
        add_event('start', instance_model, parent_event, e) if parent_event
      end

      def create_vm(instance_plan, deployment_plan, instance_model)
        task_checkpoint

        agent_broadcaster = AgentBroadcaster.new
        dns_encoder = LocalDnsEncoderManager.create_dns_encoder(
          deployment_plan.use_short_dns_addresses?,
          deployment_plan.use_link_dns_names?,
        )
        link_provider_intents = deployment_plan.link_provider_intents

        vm_creator = VmCreator.new(
          @logger,
          deployment_plan.template_blob_cache,
          dns_encoder,
          agent_broadcaster,
          link_provider_intents,
        )

        vm_creator.create_for_instance_plan(
          instance_plan,
          deployment_plan.ip_provider,
          instance_model.active_persistent_disk_cids,
          instance_plan.tags,
          true,
        )

        local_dns_manager = LocalDnsManager.create(Config.root_domain, @logger)
        local_dns_manager.update_dns_record_for_instance(instance_plan)
      end

      def add_event(action, instance_model, parent_id = nil, error = nil)
        instance_name = instance_model.name
        deployment_name = instance_model.deployment.name

        event = event_manager.create_event(
          parent_id: parent_id,
          user: username,
          action: action,
          object_type: 'instance',
          object_name: instance_name,
          task: task_id,
          deployment: deployment_name,
          instance: instance_name,
          error: error,
        )
        event.id
      end
    end
  end
end
