module Bosh::Director
  # DeploymentPlan::Assembler is used to populate deployment plan with information
  # about existing deployment and information from director DB
  class DeploymentPlan::Assembler
    include LockHelper
    include IpUtil
    include LegacyDeploymentHelper

    def self.create(deployment_plan)
      new(deployment_plan, Api::StemcellManager.new, PowerDnsManagerProvider.create)
    end

    def initialize(deployment_plan, stemcell_manager, powerdns_manager)
      @deployment_plan = deployment_plan
      @logger = Config.logger
      @stemcell_manager = stemcell_manager
      @powerdns_manager = powerdns_manager
    end

    def bind_models(options = {})
      @logger.info('Binding models')

      should_bind_links = options.fetch(:should_bind_links, true)
      should_bind_properties = options.fetch(:should_bind_properties, true)
      should_bind_new_variable_set = options.fetch(:should_bind_new_variable_set, false)
      deployment_options = @deployment_plan.deployment_wide_options
      fix = deployment_options.fetch(:fix, false)
      tags = deployment_options.fetch(:tags, {})
      instances = options.fetch(:instances, @deployment_plan.candidate_existing_instances)

      bind_releases

      migrate_legacy_dns_records

      network_reservation_repository = Bosh::Director::DeploymentPlan::NetworkReservationRepository.new(@deployment_plan, @logger)
      states_by_existing_instance = current_states_by_instance(instances, fix)

      migrate_existing_instances_to_global_networking(network_reservation_repository, states_by_existing_instance)

      instance_repo = Bosh::Director::DeploymentPlan::InstanceRepository.new(network_reservation_repository, @logger)
      index_assigner = Bosh::Director::DeploymentPlan::PlacementPlanner::IndexAssigner.new(@deployment_plan.model)
      instance_plan_factory = Bosh::Director::DeploymentPlan::InstancePlanFactory.new(
        instance_repo,
        states_by_existing_instance,
        @deployment_plan.skip_drain,
         index_assigner,
        network_reservation_repository,
        {
          'recreate' => @deployment_plan.recreate,
          'use_dns_addresses' => @deployment_plan.use_dns_addresses?,
          'use_short_dns_addresses' => @deployment_plan.use_short_dns_addresses?,
          'tags' => tags,
        },
      )
      instance_planner = Bosh::Director::DeploymentPlan::InstancePlanner.new(instance_plan_factory, @logger)
      desired_instance_groups = @deployment_plan.instance_groups

      job_migrator = Bosh::Director::DeploymentPlan::JobMigrator.new(@deployment_plan, @logger)

      desired_instance_groups.each do |desired_instance_group|
        desired_instances = desired_instance_group.desired_instances
        existing_instances = job_migrator.find_existing_instances(desired_instance_group)
        instance_plans = instance_planner.plan_instance_group_instances(desired_instance_group, desired_instances, existing_instances)
        desired_instance_group.add_instance_plans(instance_plans)
      end

      instance_plans_for_obsolete_instance_groups = instance_planner.plan_obsolete_instance_groups(desired_instance_groups, @deployment_plan.existing_instances)
      @deployment_plan.mark_instance_plans_for_deletion(instance_plans_for_obsolete_instance_groups)

      bind_stemcells
      bind_templates
      bind_properties if should_bind_properties
      bind_instance_networks
      bind_dns
      bind_links if should_bind_links
      bind_new_variable_set if should_bind_new_variable_set
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
      is_version_1_manifest = ignore_cloud_config?(@deployment_plan.uninterpolated_manifest_text)

      ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
        existing_instances.each do |existing_instance|
          if existing_instance.vm_cid && (!existing_instance.ignore || is_version_1_manifest)
            pool.process do
              with_thread_name("binding agent state for (#{existing_instance}") do
                # getting current state to obtain IP of dynamic networks
                begin
                  state = DeploymentPlan::AgentStateMigrator.new(@logger).get_state(existing_instance)
                rescue Bosh::Director::RpcTimeout => e
                  if fix
                    state = {'job_state' => 'unresponsive'}
                  else
                    raise e
                  end
                end
                lock.synchronize do
                  current_states_by_existing_instance.merge!(existing_instance => state)
                end
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
      links_resolver = DeploymentPlan::LinksResolver.new(@deployment_plan, @logger)

      @deployment_plan.instance_groups.each do |instance_group|
        links_resolver.resolve(instance_group)
      end
    end

    # Binds template models for each release spec in the deployment plan
    # @return [void]
    def bind_templates
      @deployment_plan.releases.each do |release|
        release.bind_templates
      end

      @deployment_plan.instance_groups.each do |job|
        job.validate_package_names_do_not_collide!
      end
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
      if @deployment_plan.resource_pools && @deployment_plan.resource_pools.any?
        @deployment_plan.resource_pools.each do |resource_pool|
          stemcell = resource_pool.stemcell

          if stemcell.nil?
            raise DirectorError,
              "Stemcell not bound for resource pool '#{resource_pool.name}'"
          end

          stemcell.bind_model(@deployment_plan.model)
        end
        return
      end

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

    def migrate_existing_instances_to_global_networking(network_reservation_repository, states_by_existing_instance)
      return unless @deployment_plan.using_global_networking?

      # in the case where this is their first transition to global networking, we need to make sure we have already
      # populated the database/models with the existing IPs. Do this first before we start any of our planning.
      @deployment_plan.instance_models.each do |existing_instance|
        network_reservation_repository.migrate_existing_instance_network_reservations(
          existing_instance,
          states_by_existing_instance[existing_instance]
        )
      end
    end
  end
end
