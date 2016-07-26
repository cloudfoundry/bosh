module Bosh
  module Director
    module DeploymentPlan
      class InstancePlanFactory
        def initialize(instance_repo, states_by_existing_instance, skip_drain_decider, index_assigner, network_reservation_repository, options = {})
          @instance_repo = instance_repo
          @skip_drain_decider = skip_drain_decider
          @recreate_deployment = options.fetch('recreate', false)
          @states_by_existing_instance = states_by_existing_instance
          @index_assigner = index_assigner
          @network_reservation_repository = network_reservation_repository
          @fix = options.fetch('fix', false)
        end

        def obsolete_instance_plan(existing_instance_model)
          existing_instance_state = instance_state(existing_instance_model)
          need_to_fix = (@fix && existing_instance_state.key?('current_state') && existing_instance_state['current_state'] == 'unresponsive')
          existing_instance_state = {} if need_to_fix
          @network_reservation_repository.fetch_network_reservations(existing_instance_model, existing_instance_state)
          InstancePlan.new(
            desired_instance: nil,
            existing_instance: existing_instance_model,
            instance: nil,
            skip_drain: @skip_drain_decider.for_job(existing_instance_model.job),
            recreate_deployment: @recreate_deployment,
            need_to_fix: need_to_fix
          )
        end

        def desired_existing_instance_plan(existing_instance_model, desired_instance)
          existing_instance_state = instance_state(existing_instance_model)
          need_to_fix = (@fix && existing_instance_state.key?('current_state') && existing_instance_state['current_state'] == 'unresponsive')
          existing_instance_state = {} if need_to_fix
          desired_instance.index = @index_assigner.assign_index(desired_instance.job.name, existing_instance_model)

          instance = @instance_repo.fetch_existing(existing_instance_model, existing_instance_state, desired_instance.job, desired_instance.index, desired_instance.deployment)
          instance.update_description
          InstancePlan.new(
            desired_instance: desired_instance,
            existing_instance: existing_instance_model,
            instance: instance,
            skip_drain: @skip_drain_decider.for_job(desired_instance.job.name),
            recreate_deployment: @recreate_deployment,
            need_to_fix: need_to_fix)
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

        private

        def instance_state(existing_instance_model)
          @states_by_existing_instance[existing_instance_model]
        end
      end
    end
  end
end
