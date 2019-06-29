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

          deployment_plan = DeploymentPlan::PlannerFactory.create(@logger)
            .create_from_model(instance_model.deployment)
          deployment_plan.releases.each(&:bind_model)

          instance_group = deployment_plan.instance_groups.find { |ig| ig.name == instance_model.job }
          instance_group.jobs.each(&:bind_models)

          instance_plan = construct_instance_plan(instance_model, deployment_plan, instance_group)

          event_log = Config.event_log
          if instance_model.vm_cid.nil?
            event_log_stage = event_log.begin_stage("Creating VM for instance #{instance_model.job}")
            event_log_stage.advance_and_track(instance_plan.instance.model.to_s) do
              create_vm(instance_plan, deployment_plan, instance_model)
            end
          end

          return unless instance_plan.state_changed?

          event_log_stage = event_log.begin_stage("Starting instance #{instance_model.job}")
          event_log_stage.advance_and_track(instance_plan.instance.model.to_s) do
            start(instance_plan, instance_model)
          end
        end
      end

      private

      def start(instance_plan, instance_model)
        blobstore_client = App.instance.blobstores.blobstore
        agent = AgentClient.with_agent_id(instance_model.agent_id, instance_model.name)

        templates_persister = RenderedTemplatesPersister.new(blobstore_client, @logger)
        templates_persister.persist(instance_plan)
        cleaner = RenderedJobTemplatesCleaner.new(instance_model, blobstore_client, @logger)

        instance_model.update(update_completed: false)
        InstanceUpdater::StateApplier.new(instance_plan, agent, cleaner, @logger, {}).apply(
          instance_plan.desired_instance.instance_group.update,
          true,
        )
        instance_model.update(update_completed: true)

        instance_model.update(state: 'started')
      end

      def create_vm(instance_plan, deployment_plan, instance_model)
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

      def construct_instance_plan(instance_model, deployment_plan, instance_group)
        desired_instance = DeploymentPlan::DesiredInstance.new(
          instance_group,
          deployment_plan,
          nil,
          instance_model.index,
          'started',
        )

        state_migrator = DeploymentPlan::AgentStateMigrator.new(@logger)
        existing_instance_state = instance_model.vm_cid ? state_migrator.get_state(instance_model) : {}

        variables_interpolator = ConfigServer::VariablesInterpolator.new

        instance_repository = DeploymentPlan::InstanceRepository.new(@logger, variables_interpolator)
        instance = instance_repository.build_instance_from_model(
          instance_model,
          existing_instance_state,
          desired_instance.state,
        )

        DeploymentPlan::InstancePlanFromDB.new(
          existing_instance: instance_model,
          desired_instance: desired_instance,
          instance: instance,
          variables_interpolator: variables_interpolator,
          tags: instance.deployment_model.tags,
          link_provider_intents: deployment_plan.link_provider_intents,
        )
      end
    end
  end
end
