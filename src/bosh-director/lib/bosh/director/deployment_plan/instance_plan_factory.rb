module Bosh
  module Director
    module DeploymentPlan
      class InstancePlanFactory
        # rubocop:disable Metrics/ParameterLists
        def initialize(
          instance_repo,
          states_by_existing_instance,
          deployment_plan,
          index_assigner,
          variables_interpolator,
          link_provider_intents,
          options = {}
        )
          # rubocop:enable Metrics/ParameterLists

          @deployment_plan = deployment_plan
          @instance_repo = instance_repo
          @recreate_deployment = options.fetch('recreate', false)
          @recreate_persistent_disks = options.fetch('recreate_persistent_disks', false)
          @recreate_vm_created_before = options.fetch('recreate_vm_created_before', nil)
          @states_by_existing_instance = states_by_existing_instance
          @index_assigner = index_assigner
          @link_provider_intents = link_provider_intents
          @use_dns_addresses = options.fetch('use_dns_addresses', false)
          @use_short_dns_addresses = options.fetch('use_short_dns_addresses', false)
          @use_link_dns_addresses = options.fetch('use_link_dns_addresses', false)
          @randomize_az_placement = options.fetch('randomize_az_placement', false)
          @tags = options.fetch('tags', {})
          @variables_interpolator = variables_interpolator
        end

        def obsolete_instance_plan(existing_instance_model)
          existing_instance_state = instance_state(existing_instance_model)
          instance = @instance_repo.fetch_obsolete_existing(existing_instance_model, existing_instance_state, @deployment_plan)
          InstancePlan.new(
            desired_instance: nil,
            existing_instance: existing_instance_model,
            instance: instance,
            skip_drain: @deployment_plan.skip_drain.for_job(existing_instance_model.job),
            recreate_deployment: @recreate_deployment,
            recreate_vm_created_before: @recreate_vm_created_before,
            use_dns_addresses: @use_dns_addresses,
            use_short_dns_addresses: @use_short_dns_addresses,
            use_link_dns_addresses: @use_link_dns_addresses,
            variables_interpolator: @variables_interpolator,
            link_provider_intents: @link_provider_intents,
          )
        end

        def desired_existing_instance_plan(existing_instance_model, desired_instance)
          existing_instance_state = instance_state(existing_instance_model)
          desired_instance.index = @index_assigner.assign_index(desired_instance.instance_group.name, existing_instance_model)

          instance = @instance_repo.fetch_existing(existing_instance_model, existing_instance_state, desired_instance)
          instance.update_description
          InstancePlan.new(
            desired_instance: desired_instance,
            existing_instance: existing_instance_model,
            instance: instance,
            skip_drain: @deployment_plan.skip_drain.for_job(desired_instance.instance_group.name),
            recreate_deployment: @recreate_deployment,
            recreate_persistent_disks: @recreate_persistent_disks,
            recreate_vm_created_before: @recreate_vm_created_before,
            use_dns_addresses: @use_dns_addresses,
            use_short_dns_addresses: @use_short_dns_addresses,
            use_link_dns_addresses: @use_link_dns_addresses,
            tags: @tags,
            variables_interpolator: @variables_interpolator,
            link_provider_intents: @link_provider_intents,
          )
        end

        def desired_new_instance_plan(desired_instance)
          desired_instance.index = @index_assigner.assign_index(desired_instance.instance_group.name)

          instance = @instance_repo.create(desired_instance, desired_instance.index)
          InstancePlan.new(
            desired_instance: desired_instance,
            existing_instance: nil,
            instance: instance,
            skip_drain: @deployment_plan.skip_drain.for_job(desired_instance.instance_group.name),
            recreate_deployment: @recreate_deployment,
            recreate_vm_created_before: @recreate_vm_created_before,
            use_dns_addresses: @use_dns_addresses,
            use_short_dns_addresses: @use_short_dns_addresses,
            use_link_dns_addresses: @use_link_dns_addresses,
            tags: @tags,
            variables_interpolator: @variables_interpolator,
            link_provider_intents: @link_provider_intents,
          )
        end

        def randomize_az_placement?
          @randomize_az_placement
        end

        private

        def instance_state(existing_instance_model)
          @states_by_existing_instance[existing_instance_model]
        end
      end
    end
  end
end
