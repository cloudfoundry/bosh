module Bosh::Director
  # DeploymentPlan::Assembler is used to populate deployment plan with information
  # about existing deployment and information from director DB
  class DeploymentPlan::Assembler
    include LockHelper
    include IpUtil

    def self.create(deployment_plan, variables_interpolator)
      new(deployment_plan, Api::StemcellManager.new, PowerDnsManagerProvider.create, variables_interpolator)
    end

    def initialize(deployment_plan, stemcell_manager, powerdns_manager, variables_interpolator)
      @deployment_plan = deployment_plan
      @logger = Config.logger
      @stemcell_manager = stemcell_manager
      @powerdns_manager = powerdns_manager
      @links_manager = Bosh::Director::Links::LinksManager.new(deployment_plan.model.links_serial_id)
      @variables_interpolator = variables_interpolator
    end

    def bind_models(options = {})
      @logger.info('Binding models')

      is_deploy_action = options.fetch(:is_deploy_action, false)
      should_bind_links = is_deploy_action && options.fetch(:should_bind_links, true)
      should_bind_properties = options.fetch(:should_bind_properties, true)
      should_bind_new_variable_set = options.fetch(:should_bind_new_variable_set, false)
      stemcell_change = options.fetch(:stemcell_change, false)
      deployment_options = @deployment_plan.deployment_wide_options
      fix = deployment_options.fetch(:fix, false)
      tags = deployment_options.fetch(:tags, {})
      instances = options.fetch(:instances, @deployment_plan.candidate_existing_instances)

      bind_releases
      bind_stemcells

      migrate_legacy_dns_records

      states_by_existing_instance = current_states_by_instance(instances, fix)

      instance_repo = Bosh::Director::DeploymentPlan::InstanceRepository.new(@logger, @variables_interpolator)
      index_assigner = Bosh::Director::DeploymentPlan::PlacementPlanner::IndexAssigner.new(@deployment_plan.model)
      instance_plan_factory = Bosh::Director::DeploymentPlan::InstancePlanFactory.new(
        instance_repo,
        states_by_existing_instance,
        @deployment_plan,
        index_assigner,
        @variables_interpolator,
        @deployment_plan.link_provider_intents,
        'recreate' => @deployment_plan.recreate,
        'use_dns_addresses' => @deployment_plan.use_dns_addresses?,
        'use_short_dns_addresses' => @deployment_plan.use_short_dns_addresses?,
        'use_link_dns_addresses' => @deployment_plan.use_link_dns_names?,
        'recreate_persistent_disks' => @deployment_plan.recreate_persistent_disks?,
        'randomize_az_placement' => @deployment_plan.randomize_az_placement?,
        'tags' => tags,
      )
      instance_planner = Bosh::Director::DeploymentPlan::InstancePlanner.new(instance_plan_factory, @logger)
      desired_instance_groups = @deployment_plan.instance_groups

      job_migrator = Bosh::Director::DeploymentPlan::JobMigrator.new(@deployment_plan, @logger)

      desired_instance_groups.each do |desired_instance_group|
        unless desired_instance_group.migrated_from.to_a.empty?
          @links_manager.migrate_links_provider_instance_group(@deployment_plan.model, desired_instance_group)
          @links_manager.migrate_links_consumer_instance_group(@deployment_plan.model, desired_instance_group)
        end

        desired_instances = desired_instance_group.desired_instances
        existing_instances = job_migrator.find_existing_instances(desired_instance_group)

        instance_plans = instance_planner.plan_instance_group_instances(
          desired_instance_group,
          desired_instances,
          existing_instances,
          @deployment_plan.vm_resources_cache,
        )
        instance_planner.orphan_unreusable_vms(
          instance_plans,
          existing_instances,
        )
        instance_planner.reconcile_network_plans(instance_plans)
        desired_instance_group.add_instance_plans(instance_plans)

        desired_instance_group.unignored_instance_plans.each do |instance_plan|
          instance_plan.instance.is_deploy_action = is_deploy_action
        end
      end

      instance_plans_for_obsolete_instance_groups = instance_planner.plan_obsolete_instance_groups(
        desired_instance_groups,
        @deployment_plan.existing_instances,
      )
      @deployment_plan.mark_instance_plans_for_deletion(instance_plans_for_obsolete_instance_groups)

      bind_jobs
      bind_properties if should_bind_properties
      bind_new_variable_set if should_bind_new_variable_set # should_bind_new is true when doing deploy action
      bind_instance_networks
      resolve_network_plans_for_create_swap_deleted_instances(desired_instance_groups)
      bind_instance_networks
      bind_dns
      bind_links if should_bind_links
      generate_variables(stemcell_change) if is_deploy_action
    end

    private

    def bind_new_variable_set
      current_variable_set = @deployment_plan.model.current_variable_set

      @deployment_plan.instance_groups.each do |instance_group|
        instance_group.bind_new_variable_set(current_variable_set)
      end
    end

    # Binds release DB record(s) to a plan
    # @return [void]
    def bind_releases
      releases = @deployment_plan.releases
      with_release_locks(releases.map(&:name)) do
        releases.each do |release|
          release.bind_model
        end
      end
    end

    def current_states_by_instance(existing_instances, fix = false)
      lock = Mutex.new
      current_states_by_existing_instance = {}

      ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
        existing_instances.each do |existing_instance|
          next unless existing_instance.vm_cid && !existing_instance.ignore

          pool.process do
            with_thread_name("binding agent state for (#{existing_instance}") do
              # getting current state to obtain IP of dynamic networks
              state = DeploymentPlan::AgentStateMigrator.new(@logger).get_state(existing_instance, fix)

              lock.synchronize do
                current_states_by_existing_instance.merge!(existing_instance => state)
              end
            end
          end
        end
      end
      current_states_by_existing_instance
    end

    def bind_instance_networks
      # CHANGEME: something about instance plan's new network plans
      @deployment_plan.instance_groups_starting_on_deploy.each do |instance_group|
        instance_group.bind_instance_networks(@deployment_plan.ip_provider)
      end
    end

    def bind_links
      @links_manager.update_provider_intents_contents(@deployment_plan.model.link_providers, @deployment_plan)

      resolve_link_options = {
        dry_run: false,
        global_use_dns_entry: @deployment_plan.use_dns_addresses?
      }

      @links_manager.resolve_deployment_links(@deployment_plan.model, resolve_link_options)
      if @deployment_plan.model.has_stale_errand_links
        @deployment_plan.model.has_stale_errand_links = false
        @deployment_plan.model.save
      end
    end

    def generate_variables(stemcell_change)
      @variables_interpolator.generate_values(
        @deployment_plan.variables,
        @deployment_plan.name,
        @deployment_plan.features.converge_variables,
        @deployment_plan.features.use_link_dns_names,
        stemcell_change,
      )
    end

    # Binds template models for each release spec in the deployment plan
    # @return [void]
    def bind_jobs
      @deployment_plan.releases.each do |release|
        release.bind_jobs
      end

      @deployment_plan.instance_groups.each(&:validate_package_names_do_not_collide!)
      @deployment_plan.instance_groups.each(&:validate_exported_from_matches_stemcell!)
    end

    # Binds properties for all templates in the deployment
    # @return [void]
    def bind_properties
      @deployment_plan.instance_groups.each do |instance_group|
        instance_group.bind_properties
      end
    end

    # Binds stemcell model for each stemcell spec in
    # the deployment plan
    # @return [void]
    def bind_stemcells
      @deployment_plan.stemcells.each do |_, stemcell|
        stemcell.bind_model(@deployment_plan.model)
      end
    end

    def bind_dns
      @powerdns_manager.configure_nameserver
    end

    def migrate_legacy_dns_records
      @deployment_plan.instance_models.each do |instance_model|
        @powerdns_manager.migrate_legacy_records(instance_model)
      end
    end

    def resolve_network_plans_for_create_swap_deleted_instances(desired_instance_groups)
      network_planner = DeploymentPlan::NetworkPlanner::Planner.new(@logger)

      desired_instance_groups.each do |desired_instance_group|
        desired_instance_group.sorted_instance_plans.each do |desired_instance_plan|
          next unless desired_instance_plan.should_create_swap_delete? && desired_instance_plan.recreate_for_non_network_reasons?
          next unless desired_instance_plan.network_plans.select(&:desired?).empty?

          desired_instance_group.networks.each do |network|
            plan = network_planner.network_plan_with_dynamic_reservation(desired_instance_plan, network)
            desired_instance_plan.network_plans << plan
          end

          desired_instance_plan.network_plans.select(&:existing?).each do |network_plan|
            network_plan.existing = false
            network_plan.obsolete = true
          end
        end
      end
    end
  end
end
