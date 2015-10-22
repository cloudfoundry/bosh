module Bosh
  module Director
    module DeploymentPlan
      class InstancePlanFactory
        def initialize(instance_repo, states_by_existing_instance, skip_drain_decider, index_assigner, options = {})
          @instance_repo = instance_repo
          @skip_drain_decider = skip_drain_decider
          @recreate_deployment = options.fetch('recreate', false)
          @states_by_existing_instance = states_by_existing_instance
          @index_assigner = index_assigner
        end

        def obsolete_instance_plan(existing_instance_model)
          InstancePlan.new(
            desired_instance: nil,
            existing_instance: existing_instance_model,
            instance: nil,
            skip_drain: @skip_drain_decider.for_job(existing_instance_model.job),
            recreate_deployment: @recreate_deployment
          )
        end

        def desired_existing_instance_plan(existing_instance_model, desired_instance)
          existing_instance_state = @states_by_existing_instance[existing_instance_model]

          desired_instance.index = @index_assigner.assign_index(desired_instance.job.name, existing_instance_model)

          instance = @instance_repo.fetch_existing(desired_instance, existing_instance_model, existing_instance_state)
          instance.update_description
          InstancePlan.new(
            desired_instance: desired_instance,
            existing_instance: existing_instance_model,
            instance: instance,
            skip_drain: @skip_drain_decider.for_job(desired_instance.job.name),
            recreate_deployment: @recreate_deployment
          )
        end

        def desired_new_instance_plan(desired_instance)
          desired_instance.index = @index_assigner.assign_index(desired_instance.job.name)

          instance = @instance_repo.create(desired_instance, desired_instance.index)
          InstancePlan.new(
            desired_instance: desired_instance,
            existing_instance: nil,
            instance: instance,
            skip_drain: @skip_drain_decider.for_job(desired_instance.job.name),
            recreate_deployment: @recreate_deployment
          )
        end
      end
    end
  end
end
