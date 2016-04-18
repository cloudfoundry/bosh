module Bosh::Director
  # DeploymentPlan::Assembler is used to populate deployment plan with information
  # about existing deployment and information from director DB
  class DeploymentPlan::Assembler
    include LockHelper
    include IpUtil

    def initialize(deployment_plan, stemcell_manager, dns_manager, cloud, logger)
      @deployment_plan = deployment_plan
      @cloud = cloud
      @logger = logger
      @stemcell_manager = stemcell_manager
      @dns_manager = dns_manager
    end

    def bind_models(skip_links_binding = false)
      @logger.info('Binding models')
      bind_releases

      migrate_legacy_dns_records
      network_reservation_repository = Bosh::Director::DeploymentPlan::NetworkReservationRepository.new(@deployment_plan, @logger)
      instance_repo = Bosh::Director::DeploymentPlan::InstanceRepository.new(network_reservation_repository, @logger)
      states_by_existing_instance = current_states_by_instance(@deployment_plan.candidate_existing_instances)
      index_assigner = Bosh::Director::DeploymentPlan::PlacementPlanner::IndexAssigner.new(@deployment_plan.model)
      instance_plan_factory = Bosh::Director::DeploymentPlan::InstancePlanFactory.new(instance_repo, states_by_existing_instance, @deployment_plan.skip_drain, index_assigner, network_reservation_repository, {'recreate' => @deployment_plan.recreate})
      instance_planner = Bosh::Director::DeploymentPlan::InstancePlanner.new(instance_plan_factory, @logger)
      desired_jobs = @deployment_plan.jobs

      job_migrator = Bosh::Director::DeploymentPlan::JobMigrator.new(@deployment_plan, @logger)

      desired_jobs.each do |desired_job|
        desired_instances = desired_job.desired_instances
        existing_instances = job_migrator.find_existing_instances(desired_job)
        instance_plans = instance_planner.plan_job_instances(desired_job, desired_instances, existing_instances)
        desired_job.add_instance_plans(instance_plans)
      end

      instance_plans_for_obsolete_jobs = instance_planner.plan_obsolete_jobs(desired_jobs, @deployment_plan.existing_instances)
      instance_plans_for_obsolete_jobs.map(&:existing_instance).each { |existing_instance| @deployment_plan.mark_instance_for_deletion(existing_instance) }

      bind_stemcells
      bind_templates
      bind_properties
      bind_instance_networks
      bind_dns

      if (!skip_links_binding)
        bind_links
      end

    end

    private

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

    def current_states_by_instance(existing_instances)
      lock = Mutex.new
      current_states_by_existing_instance = {}
      ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
        existing_instances.each do |existing_instance|
          if existing_instance.vm_cid
            pool.process do
              with_thread_name("binding agent state for (#{existing_instance}") do
                # getting current state to obtain IP of dynamic networks
                state = DeploymentPlan::AgentStateMigrator.new(@deployment_plan, @logger).get_state(existing_instance)
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
      @deployment_plan.jobs_starting_on_deploy.each do |job|
        job.bind_instance_networks(@deployment_plan.ip_provider)
      end
    end

    def bind_links
      links_resolver = Bosh::Director::DeploymentPlan::LinksResolver.new(@deployment_plan, @logger)

      @deployment_plan.jobs.each do |job|
        links_resolver.resolve(job)
      end
    end

    # Binds template models for each release spec in the deployment plan
    # @return [void]
    def bind_templates
      @deployment_plan.releases.each do |release|
        release.bind_templates
      end

      @deployment_plan.jobs.each do |job|
        job.validate_package_names_do_not_collide!
      end
    end

    # Binds properties for all templates in the deployment
    # @return [void]
    def bind_properties
      @deployment_plan.jobs.each do |job|
        job.bind_properties
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
      @dns_manager.configure_nameserver
    end

    def migrate_legacy_dns_records
      @deployment_plan.instance_models.each do |instance_model|
        @dns_manager.migrate_legacy_records(instance_model)
      end
    end
  end
end
