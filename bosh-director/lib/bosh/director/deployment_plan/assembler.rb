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

    def bind_models
      @logger.info('Binding models')
      bind_releases

      migrate_legacy_dns_records
      bind_job_renames

      instance_repo = Bosh::Director::DeploymentPlan::InstanceRepository.new(@logger)
      states_by_existing_instance = current_states_by_instance(@deployment_plan.candidate_existing_instances)
      index_assigner = Bosh::Director::DeploymentPlan::PlacementPlanner::IndexAssigner.new(@deployment_plan.model)
      instance_plan_factory = Bosh::Director::DeploymentPlan::InstancePlanFactory.new(instance_repo, states_by_existing_instance, @deployment_plan.skip_drain, index_assigner, {'recreate' => @deployment_plan.recreate})
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

      mark_unknown_vms_for_deletion

      bind_stemcells
      bind_templates
      bind_properties
      bind_unallocated_vms
      bind_instance_networks
      bind_dns
      bind_links
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
          if existing_instance.vm
            pool.process do
              with_thread_name("binding agent state for (#{existing_instance.job}/#{existing_instance.index})") do
                # getting current state to obtain IP of dynamic networks
                state = DeploymentPlan::AgentStateMigrator.new(@deployment_plan, @logger).get_state(existing_instance.vm)
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

    def mark_unknown_vms_for_deletion
      @deployment_plan.vm_models.select { |vm| vm.instance.nil? }.each do |vm_model|
        # VM without an instance should not exist any more. But we still
        # delete those VMs for backwards compatibility in case if it was ever
        # created incorrectly.
        # It also means that it was created before global networking
        # and should not have any network reservations in DB,
        # so we don't worry about releasing its IPs.
        @logger.debug('Marking VM for deletion')
        @deployment_plan.mark_vm_for_deletion(vm_model)
      end
    end

    # Looks at every job instance in the deployment plan and binds it to the
    # instance database model (idle VM is also created in the appropriate
    # resource pool if necessary)
    # @return [void]
    def bind_unallocated_vms
      @deployment_plan.jobs_starting_on_deploy.each(&:bind_unallocated_vms)
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
              "Stemcell not bound for resource pool `#{resource_pool.name}'"
          end

          stemcell.bind_model(@deployment_plan)
        end
        return
      end

      @deployment_plan.stemcells.each do |_, stemcell|
        stemcell.bind_model(@deployment_plan)
      end
    end

    def bind_dns
      @dns_manager.configure_nameserver
    end

    def bind_job_renames
      @deployment_plan.instance_models.each do |instance_model|
        update_instance_if_rename(instance_model)
      end
    end

    def migrate_legacy_dns_records
      @deployment_plan.instance_models.each do |instance_model|
        @dns_manager.migrate_legacy_records(instance_model)
      end
    end

    def update_instance_if_rename(instance_model)
      if @deployment_plan.rename_in_progress?
        old_name = @deployment_plan.job_rename['old_name']
        new_name = @deployment_plan.job_rename['new_name']

        if instance_model.job == old_name
          @logger.info("Renaming `#{old_name}' to `#{new_name}'")
          instance_model.update(:job => new_name)
        end
      end
    end
  end
end
