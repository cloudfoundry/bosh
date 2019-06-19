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
          instance_model = Models::Instance.find(id: @instance_id)
          raise InstanceNotFound if instance_model.nil?

          return if instance_model.stopped? && !@options['hard'] # stopped already, and we didn't pass in hard to change it
          return if instance_model.detached? # implies stopped

          deployment_plan = DeploymentPlan::PlannerFactory.create(@logger)
            .create_from_model(instance_model.deployment)
          deployment_plan.releases.each(&:bind_model)

          instance_group = deployment_plan.instance_groups.find { |ig| ig.name == instance_model.job }
          instance_group.jobs.each(&:bind_models)

          instance_plan = construct_instance_plan(instance_model, deployment_plan, instance_group, @options)

          event_log = Config.event_log
          event_log_stage = event_log.begin_stage("Stopping instance #{instance_model.job}")
          event_log_stage.advance_and_track(instance_plan.instance.model.to_s) do
            stop(instance_plan, instance_model)
          end

          if @options['hard']
            event_log_stage = event_log.begin_stage('Deleting VM')
            event_log_stage.advance_and_track(instance_model.vm_cid) do
              detach_instance(instance_model)
            end
          end
        end
      end

      private

      def detach_instance(instance_model)
        instance_report = DeploymentPlan::Stages::Report.new.tap { |r| r.vm = instance_model.active_vm }
        DeploymentPlan::Steps::UnmountInstanceDisksStep.new(instance_model).perform(instance_report)
        DeploymentPlan::Steps::DeleteVmStep.new(true, false, Config.enable_virtual_delete_vms).perform(instance_report)
        @logger.debug("Setting instance #{@instance_id} state to detached")
        instance_model.update(state: 'detached')
      end

      def stop(instance_plan, instance_model)
        intent = @options['hard'] ? :delete_vm : :keep_vm
        target_state = @options['hard'] ? 'detached' : 'stopped'
        Stopper.stop(intent: intent, instance_plan: instance_plan, target_state: target_state, logger: @logger)

        Api::SnapshotManager.take_snapshot(instance_model, clean: true)
        @logger.debug("Setting instance #{@instance_id} state to stopped")
        instance_model.update(state: 'stopped')
      end

      def construct_instance_plan(instance_model, deployment_plan, instance_group, options)
        desired_instance = DeploymentPlan::DesiredInstance.new(instance_group, deployment_plan) # index?
        variables_interpolator = ConfigServer::VariablesInterpolator.new

        instance_repository = DeploymentPlan::InstanceRepository.new(@logger, variables_interpolator)
        instance = instance_repository.fetch_existing(
          instance_model,
          instance_model.state,
          instance_group,
          instance_model.index,
          deployment_plan,
        )

        network_plans = instance.existing_network_reservations.map do |reservation|
          DeploymentPlan::NetworkPlanner::Plan.new(reservation: reservation, existing: true)
        end

        DeploymentPlan::InstancePlan.new(
          existing_instance: instance_model,
          desired_instance: desired_instance,
          instance: instance,
          variables_interpolator: variables_interpolator,
          network_plans: network_plans,
          skip_drain: options['skip_drain'],
        )
      end
    end
  end
end
