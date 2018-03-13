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
      event_log_stage.advance_and_track('Preparing deployment') do
        deployment_planner = @deployment_planner_provider.get_by_name(deployment_name)
        dns_encoder = LocalDnsEncoderManager.new_encoder_with_updated_index(deployment_planner.availability_zones.map(&:name))
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
          if !deployment_planner.instance_group(errand_name).nil?
            Config.event_log.warn("Ambiguous request: the requested errand name '#{errand_name}' matches both a job " +
              "name and an errand instance group name. Executing errand on all relevant instances with job '#{errand_name}'.")
          end
        end

        runner = Errand::Runner.new(errand_name, errand_is_job_name, @task_result, @instance_manager, @logs_fetcher)

        matcher = Errand::InstanceMatcher.new(requested_instances)

        errand_steps = errand_instance_groups.map do |errand_instance_group|
          errand_instance_group.bind_instances(deployment_planner.ip_provider)

          if errand_instance_group.is_errand?
            render_templates(errand_instance_group, template_blob_cache, dns_encoder)
            target_instance = errand_instance_group.instances.first
            compile_step(deployment_planner).perform

            if matcher.matches?(target_instance, errand_instance_group.instances)
              Errand::LifecycleErrandStep.new(
                runner,
                deployment_planner,
                errand_name,
                target_instance,
                errand_instance_group,
                keep_alive,
                deployment_name,
                @logger)
            end
          else
            errand_instance_group.instances.map do |target_instance|
              if matcher.matches?(target_instance, errand_instance_group.instances)
                Errand::LifecycleServiceStep.new(runner, target_instance, @logger)
              end
            end
          end
        end

        unmatched = matcher.unmatched_criteria
        if unmatched.any?
          raise "No instances match selection criteria: [#{ unmatched.join(', ') }]"
        end

        result = Errand::ParallelStep.new(Config.max_threads, errand_name, deployment_planner.model, errand_steps.flatten.compact)
      end
      result
    end

    private

    def must_errand_instance_group(deployment_planner, errand_name, deployment_name)
      errand_instance_group = deployment_planner.instance_group(errand_name)

      if errand_instance_group.nil?
        raise JobNotFound, "Errand '#{errand_name}' doesn't exist"
      end

      unless errand_instance_group.is_errand?
        raise RunErrandError,
          "Instance group '#{errand_instance_group.name}' is not an errand. To mark an instance group as an errand " +
            "set its lifecycle to 'errand' in the deployment manifest."
      end

      if errand_instance_group.instances.empty?
        raise InstanceNotFound, "Instance '#{deployment_name}/#{errand_name}/0' doesn't exist"
      end


      errand_instance_group
    end

    def render_templates(errand_instance_group, template_blob_cache, dns_encoder)
      needed_instance_plans = errand_instance_group.needed_instance_plans
      JobRenderer.render_job_instances_with_cache(needed_instance_plans, template_blob_cache, dns_encoder, @logger)
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
      DeploymentPlan::Steps::PackageCompileStep.create(deployment_plan)
    end
  end

  class Errand::DeploymentPlannerProvider
    def initialize(logger)
      @logger = logger
    end

    def get_by_name(deployment_name)
      deployment_model = Api::DeploymentManager.new.find_by_name(deployment_name)
      planner_factory = DeploymentPlan::PlannerFactory.create(@logger)
      deployment_planner = planner_factory.create_from_model(deployment_model)
      DeploymentPlan::Assembler.create(deployment_planner).bind_models
      deployment_planner
    end
  end
end
