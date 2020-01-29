module Bosh::Director
  class Errand::ErrandProvider
    def initialize(logs_fetcher, instance_manager, event_manager, logger, task_result, deployment_planner_provider)
      @instance_manager = instance_manager
      @logs_fetcher = logs_fetcher
      @event_manager = event_manager
      @logger = logger
      @task_result = task_result
      @deployment_planner_provider = deployment_planner_provider
    end

    def get(deployment_name, errand_name, keep_alive, requested_instances)
      event_log_stage = Config.event_log.begin_stage('Preparing deployment', 1)
      result = nil

      deployment = Models::Deployment.first(name: deployment_name)
      if deployment.has_stale_errand_links
        deployment.links_serial_id += 1
        deployment.save
      end
      # Models::Instance
      instances_from_db = @instance_manager.find_instances_by_deployment(deployment)

      matcher = Errand::InstanceMatcher.new(requested_instances)
      instances, unmatched_filters = matcher.match(instances_from_db)

      event_log_stage.advance_and_track('Preparing deployment') do
        deployment_planner = @deployment_planner_provider.get_by_name(deployment_name, instances)
        dns_encoder = LocalDnsEncoderManager.create_dns_encoder(deployment_planner.use_short_dns_addresses?, deployment_planner.use_link_dns_names?)
        template_blob_cache = deployment_planner.template_blob_cache

        errand_is_job_name = true
        errand_instance_groups = find_instance_groups_by_errand_job_name(errand_name, deployment_planner)

        if errand_instance_groups.empty?
          errand_is_job_name = false
          errand_instance_groups = [must_errand_instance_group(deployment_planner, errand_name, deployment_name)]
          if requested_instances.any?
            raise RunErrandError, 'Filtering by instances is not supported when running errand by instance group name'
          end
        else
          unless deployment_planner.instance_group(errand_name).nil?
            Config.event_log.warn("Ambiguous request: the requested errand name '#{errand_name}' matches both a job " \
              "name and an errand instance group name. Executing errand on all relevant instances with job '#{errand_name}'.")
          end
        end

        runner = Errand::Runner.new(errand_name, errand_is_job_name, @task_result, @instance_manager, @logs_fetcher)

        errand_steps = errand_instance_groups.map do |errand_instance_group|
          matching_instances = errand_instance_group.instances.select do |instance|
            instances.map(&:uuid).include?(instance.uuid)
          end

          if matching_instances.size > 1
            Config.event_log.warn('Executing errand on multiple instances in parallel. ' \
              'Use the `--instance` flag to run the errand on a single instance.')
          end

          if errand_instance_group.errand?
            errand_instance_group.bind_instances(deployment_planner.ip_provider)

            render_templates(errand_instance_group, template_blob_cache, dns_encoder, deployment_planner.link_provider_intents)
            target_instance = errand_instance_group.instances.first
            compile_step(deployment_planner).perform

            if matching_instances.include?(target_instance)
              Errand::LifecycleErrandStep.new(
                runner,
                deployment_planner,
                errand_name,
                target_instance,
                errand_instance_group,
                keep_alive,
                deployment_name,
                @logger,
              )
            end
          else
            matching_instances.collect do |target_instance|
              if target_instance.current_job_state.nil?
                Config.event_log.warn("Skipping instance: #{target_instance} " \
                                      'no matching VM reference was found')
                nil
              else
                Errand::LifecycleServiceStep.new(runner, target_instance, @logger)
              end
            end
          end
        end

        raise "No instances match selection criteria: [#{unmatched_filters.join(', ')}]" if unmatched_filters.any?

        result = Errand::ParallelStep.new(Config.max_threads, errand_name, deployment_planner.model, errand_steps.flatten.compact)
      end
      result
    end

    private

    def must_errand_instance_group(deployment_planner, errand_name, deployment_name)
      errand_instance_group = deployment_planner.instance_group(errand_name)

      raise JobNotFound, "Errand '#{errand_name}' doesn't exist" if errand_instance_group.nil?

      unless errand_instance_group.errand?
        raise RunErrandError,
              "Instance group '#{errand_instance_group.name}' is not an errand. To mark an instance group as an errand " \
              "set its lifecycle to 'errand' in the deployment manifest."
      end

      if errand_instance_group.instances.empty?
        raise InstanceNotFound, "Instance '#{deployment_name}/#{errand_name}/0' doesn't exist"
      end

      errand_instance_group
    end

    def render_templates(errand_instance_group, template_blob_cache, dns_encoder, link_provider_intents)
      needed_instance_plans = errand_instance_group.needed_instance_plans
      JobRenderer.render_job_instances_with_cache(
        @logger,
        needed_instance_plans,
        template_blob_cache,
        dns_encoder,
        link_provider_intents,
      )
      needed_instance_plans
    end

    def find_instance_groups_by_errand_job_name(errand_name, deployment_plan)
      instance_groups = []
      deployment_plan.instance_groups.each do |instance_group|
        instance_group.jobs.each do |job|
          instance_groups << instance_group if job.name == errand_name
        end
      end
      instance_groups
    end

    def compile_step(deployment_plan)
      DeploymentPlan::Stages::PackageCompileStage.create(deployment_plan)
    end
  end

  class Errand::DeploymentPlannerProvider
    def initialize(logger)
      @logger = logger
    end

    def get_by_name(deployment_name, instances)
      deployment_model = Api::DeploymentManager.new.find_by_name(deployment_name)
      planner_factory = DeploymentPlan::PlannerFactory.create(@logger)

      is_deploy_action = !!deployment_model.has_stale_errand_links
      options = {
          'deploy' => is_deploy_action
      }

      deployment_planner = planner_factory.create_from_model(deployment_model, options)
      variables_interpolator = Bosh::Director::ConfigServer::VariablesInterpolator.new
      DeploymentPlan::Assembler.create(deployment_planner, variables_interpolator).bind_models(instances: instances, is_deploy_action: is_deploy_action)
      deployment_planner
    end
  end
end
