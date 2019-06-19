module Bosh::Director
  module Jobs
    class StartInstance < BaseJob
      include LockHelper

      @queue = :normal

      def self.job_type
        :start_instance
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
          raise InstanceNotFound if instance_model.deployment.name != @deployment_name

          return if instance_model.state == 'started'

          deployment_plan = DeploymentPlan::PlannerFactory.create(@logger)
            .create_from_model(instance_model.deployment)
          deployment_plan.releases.each(&:bind_model)

          instance_group = deployment_plan.instance_groups.find { |ig| ig.name == instance_model.job }
          instance_group.jobs.each(&:bind_models)

          instance_plan = construct_instance_plan(instance_model, deployment_plan, instance_group)

          event_log = Config.event_log
          event_log_stage = event_log.begin_stage("Starting instance #{instance_model.job}")
          event_log_stage.advance_and_track(instance_plan.instance.model.to_s) do
            start(instance_plan, instance_model)
          end
        end
      end

      private

      def start(instance_plan, instance_model)
        agent = AgentClient.with_agent_id(instance_model.agent_id, instance_model.name)
        Starter.start(
          instance: instance_plan.instance,
          agent_client: agent,
          update_config: instance_plan.desired_instance.instance_group.update,
          logger: @logger,
        )
        instance_model.update(state: 'started')
      end

      def construct_instance_plan(instance_model, deployment_plan, instance_group)
        desired_instance = DeploymentPlan::DesiredInstance.new(instance_group, deployment_plan, instance_model.index)
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
        )
      end
    end
  end
end
