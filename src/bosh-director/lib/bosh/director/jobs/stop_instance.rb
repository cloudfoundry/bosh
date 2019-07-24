module Bosh::Director
  module Jobs
    class StopInstance < BaseJob
      include LockHelper

      @queue = :normal

      def self.job_type
        :stop_instance
      end

      def initialize(deployment_name, instance_id, options = {})
        @deployment_name = deployment_name
        @instance_id = instance_id
        @options = options
        @logger = Config.logger
      end

      def perform
        with_deployment_lock(@deployment_name) do
          perform_without_lock
        end
      end

      def perform_without_lock
        # perform_without_lock is necessary for restart and recreate so we can reuse code without multiple locks
        # extracting to another class would probably be better

        instance_model = Models::Instance.find(id: @instance_id)
        raise InstanceNotFound if instance_model.nil?

        result_msg = instance_model.name

        if (instance_model.stopped? && !@options['hard']) || instance_model.detached?
          # stopped already, and we didn't pass in hard to remove the vm or it's detached (stopped)
          return result_msg + ' already stopped'
        end

        deployment_plan = DeploymentPlan::PlannerFactory.create(@logger)
          .create_from_model(instance_model.deployment)

        instance_plan = DeploymentPlan::InstancePlanFromDB.create_from_instance_model(
          instance_model,
          deployment_plan,
          'stopped',
          @logger,
          @options,
        )

        event_log = Config.event_log
        event_log_stage = event_log.begin_stage("Stopping instance #{instance_model.job}")
        event_log_stage.advance_and_track(instance_plan.instance.model.to_s) do
          stop(instance_plan, instance_model)
        end

        if @options['hard']
          event_log_stage = event_log.begin_stage('Deleting VM')
          event_log_stage.advance_and_track(instance_model.vm_cid) do
            detach_instance(instance_model, instance_plan)
          end
        end
        result_msg
      end

      private

      def detach_instance(instance_model, instance_plan)
        instance_report = DeploymentPlan::Stages::Report.new.tap { |r| r.vm = instance_model.active_vm }
        unless instance_plan.unresponsive_agent?
          DeploymentPlan::Steps::UnmountInstanceDisksStep.new(instance_model).perform(instance_report)
          DeploymentPlan::Steps::DetachInstanceDisksStep.new(instance_model).perform(instance_report)
        end

        DeploymentPlan::Steps::DeleteVmStep.new(true, false, Config.enable_virtual_delete_vms).perform(instance_report)
        @logger.debug("Setting instance #{@instance_id} state to detached")
        instance_model.update(state: 'detached')
      end

      def stop(instance_plan, instance_model)
        intent = @options['hard'] ? :delete_vm : :keep_vm
        target_state = @options['hard'] ? 'detached' : 'stopped'
        notifier = DeploymentPlan::Notifier.new(@deployment_name, Config.nats_rpc, @logger)
        parent_event = add_event('stop', instance_model)
        notifier.send_begin_instance_event(instance_model.name, 'stop')

        Stopper.stop(intent: intent, instance_plan: instance_plan, target_state: target_state, logger: @logger)

        Api::SnapshotManager.take_snapshot(instance_model, clean: true)
        @logger.debug("Setting instance #{@instance_id} state to stopped")
        instance_model.update(state: 'stopped')
      rescue StandardError => e
        raise e
      ensure
        add_event('stop', instance_model, parent_event, e) if parent_event
        notifier.send_end_instance_event(instance_model.name, 'stop')
      end

      def add_event(action, instance_model, parent_id = nil, error = nil)
        instance_name = instance_model.name
        deployment_name = instance_model.deployment.name

        event = Config.current_job.event_manager.create_event(
          parent_id:   parent_id,
          user:        Config.current_job.username,
          action:      action,
          object_type: 'instance',
          object_name: instance_name,
          task:        Config.current_job.task_id,
          deployment:  deployment_name,
          instance:    instance_name,
          error:       error,
        )
        event.id
      end
    end
  end
end
