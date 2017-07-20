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

    def get(deployment_name, errand_name)
      event_log_stage = Config.event_log.begin_stage('Preparing deployment', 1)
      event_log_stage.advance_and_track('Preparing deployment') do
        changes_exist = true

        deployment_planner = @deployment_planner_provider.get_by_name(deployment_name)
        job_renderer = deployment_planner.job_renderer

        errand_is_job_name = true
        errand_instance_group = find_instance_group_by_errand_job_name(errand_name, deployment_planner)

        if errand_instance_group.nil?
          errand_is_job_name = false
          errand_instance_group = must_errand_instance_group(deployment_planner, errand_name, deployment_name)
        end

        if errand_instance_group.is_errand?
          @logger.info('Starting to prepare for deployment')
          errand_instance_group.bind_instances(deployment_planner.ip_provider)
          target_instance = errand_instance_group.instances.first
          needed_instance_plans = needed_instance_plans(errand_instance_group, job_renderer)
          changes_exist = changes_exist?(needed_instance_plans, target_instance)
          compile_step(deployment_planner).perform
        else
          target_instance = errand_instance_group.instances.first
        end

        runner = Errand::Runner.new(target_instance, errand_name, errand_is_job_name, @task_result, @instance_manager, @logs_fetcher)

        return Errand::ErrandStep.new(
          runner,
          deployment_planner,
          errand_name,
          errand_instance_group,
          changes_exist,
          deployment_name,
          @logger)
      end
    end

    private

    def changes_exist?(needed_instance_plans, target_instance)
      last_errand_run = Models::ErrandRun.where(instance_id: target_instance.model.id).first

      if last_errand_run
        changed_instance_plans = needed_instance_plans.select do |plan|
          if JSON.dump(plan.instance.current_packages) != last_errand_run.successful_packages_spec
            @logger.info("Packages changed FROM: #{last_errand_run.successful_packages_spec} TO: #{plan.instance.current_packages}")
            next true
          end

          if plan.instance.configuration_hash != last_errand_run.successful_configuration_hash
            @logger.info("Configuration changed FROM: #{last_errand_run.successful_configuration_hash} TO: #{plan.instance.configuration_hash}")
            next true
          end
        end

        if last_errand_run.successful && changed_instance_plans.empty?
          return false
        end
      end

      true
    end

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

    def needed_instance_plans(errand_instance_group, job_renderer)
      needed_instance_plans = errand_instance_group.needed_instance_plans
      job_renderer.render_job_instances(needed_instance_plans)
      needed_instance_plans
    end

    def find_instance_group_by_errand_job_name(errand_name, deployment_plan)
      deployment_plan.instance_groups.each do |instance_group|
        instance_group.jobs.each do |job|
          if job.name == errand_name && job.runs_as_errand?
            return instance_group
          end
        end
      end
      nil
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
