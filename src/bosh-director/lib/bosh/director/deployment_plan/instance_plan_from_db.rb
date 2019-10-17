module Bosh
  module Director
    module DeploymentPlan
      class InstancePlanFromDB < InstancePlan
        def self.create_from_instance_model(instance_model, deployment_plan, desired_state, logger, options = {})
          deployment_plan.releases.each(&:bind_model)

          instance_group = deployment_plan.instance_groups.find { |ig| ig.name == instance_model.job }
          instance_group.jobs.each(&:bind_models)

          desired_instance = DeploymentPlan::DesiredInstance.new(
            instance_group,
            deployment_plan,
            nil,
            instance_model.index,
          )
          state_migrator = DeploymentPlan::AgentStateMigrator.new(logger)

          existing_instance_state = {}
          if instance_model.vm_cid
            existing_instance_state = state_migrator.get_state(instance_model, options['ignore_unresponsive_agent'])
          end

          variables_interpolator = ConfigServer::VariablesInterpolator.new

          instance_repository = DeploymentPlan::InstanceRepository.new(logger, variables_interpolator)
          instance = instance_repository.build_instance_from_model(
            instance_model,
            existing_instance_state,
            desired_state,
            desired_instance.deployment,
          )

          new(
            existing_instance: instance_model,
            desired_instance: desired_instance,
            instance: instance,
            variables_interpolator: variables_interpolator,
            skip_drain: options['skip_drain'],
            tags: instance.deployment_model.tags,
            link_provider_intents: deployment_plan.link_provider_intents,
          )
        end

        def network_plans
          @instance.existing_network_reservations.map do |reservation|
            DeploymentPlan::NetworkPlanner::Plan.new(reservation: reservation, existing: true)
          end
        end

        def network_settings_hash
          @existing_instance.spec_p('networks')
        end

        def spec
          InstanceSpec.create_from_database(@existing_instance.spec, @instance, @variables_interpolator)
        end

        def needs_disk?
          @existing_instance.managed_persistent_disk_cid
        end

        def templates
          @existing_instance.templates.map do |template_model|
            model_release_version = @instance.model.deployment.release_versions.find do |release_version|
              release_version.templates.map(&:id).include? template_model.id
            end
            release_spec = { 'name' => model_release_version.release.name, 'version' => model_release_version.version }
            job_release_version = ReleaseVersion.parse(@instance.model.deployment, release_spec)
            job_release_version.bind_model
            template = Job.new(job_release_version, template_model.name)
            template.bind_existing_model(template_model)
            template
          end
        end
      end
    end
  end
end
