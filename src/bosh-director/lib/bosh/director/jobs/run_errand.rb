module Bosh::Director
  class Jobs::RunErrand < Jobs::BaseJob
    include LockHelper

    @queue = :normal

    def self.job_type
      :run_errand
    end

    def initialize(deployment_name, errand_name, keep_alive, when_changed)
      @deployment_name = deployment_name
      @errand_name = errand_name
      @deployment_manager = Api::DeploymentManager.new
      @instance_manager = Api::InstanceManager.new
      @keep_alive = keep_alive
      @when_changed = when_changed
      blobstore = App.instance.blobstores.blobstore
      log_bundles_cleaner = LogBundlesCleaner.new(blobstore, 60 * 60 * 24 * 10, logger) # 10 days
      @logs_fetcher = LogsFetcher.new(@instance_manager, log_bundles_cleaner, logger)
    end

    def perform
      deployment_model = @deployment_manager.find_by_name(@deployment_name)
      deployment_manifest = Manifest.load_from_model(deployment_model)
      deployment_name = deployment_manifest.to_hash['name']

      with_deployment_lock(deployment_name) do
        deployment_planner = nil
        begin
          errand_instance_group = nil

          event_log_stage = Config.event_log.begin_stage('Preparing deployment', 1)
          event_log_stage.advance_and_track('Preparing deployment') do
            planner_factory = DeploymentPlan::PlannerFactory.create(logger)
            deployment_planner = planner_factory.create_from_model(deployment_model)
            assembler = DeploymentPlan::Assembler.create(deployment_planner)
            assembler.bind_models
            errand_instance_group = deployment_planner.instance_group(@errand_name)

            if errand_instance_group.nil?
              raise JobNotFound, "Errand '#{@errand_name}' doesn't exist"
            end

            unless errand_instance_group.is_errand?
              raise RunErrandError,
                "Instance group '#{errand_instance_group.name}' is not an errand. To mark an instance group as an errand " +
                  "set its lifecycle to 'errand' in the deployment manifest."
            end

            if errand_instance_group.instances.empty?
              raise InstanceNotFound, "Instance '#{@deployment_name}/#{@errand_name}/0' doesn't exist"
            end

            logger.info('Starting to prepare for deployment')
            errand_instance_group.bind_instances(deployment_planner.ip_provider)

            deployment_planner.job_renderer.render_job_instances(errand_instance_group.needed_instance_plans)
            compile_step(deployment_planner).perform

            if @when_changed
              logger.info('Errand run with --when-changed')
              last_errand_run = Models::ErrandRun.where(instance_id: errand_instance_group.instances.first.model.id).first

              if last_errand_run
                changed_instance_plans = errand_instance_group.needed_instance_plans.select do |plan|
                  if JSON.dump(plan.instance.current_packages) != last_errand_run.successful_packages_spec
                    logger.info("Packages changed FROM: #{last_errand_run.successful_packages_spec} TO: #{plan.instance.current_packages}")
                    next true
                  end

                  if plan.instance.configuration_hash != last_errand_run.successful_configuration_hash
                    logger.info("Configuration changed FROM: #{last_errand_run.successful_configuration_hash} TO: #{plan.instance.configuration_hash}")
                    next true
                  end
                end

                if last_errand_run.successful && changed_instance_plans.empty?
                  logger.info('Skip running errand because since last errand run was successful and there have been no changes to job configuration')
                  return
                end
              end
            end
          end

          runner = Errand::Runner.new(errand_instance_group.instances.first, errand_instance_group.name, task_result, @instance_manager, @logs_fetcher)

          cancel_blk = lambda {
            begin
              task_checkpoint
            rescue TaskCancelled => e
              runner.cancel
              raise e
            end
          }

          with_updated_instances(deployment_planner, errand_instance_group) do
            logger.info('Starting to run errand')
            runner.run(&cancel_blk)
          end
        ensure
          deployment_planner.job_renderer.clean_cache!
        end
      end
    end

    def task_cancelled?
      super unless @ignore_cancellation
    end

    private

    def compile_step(deployment_plan)
      DeploymentPlan::Steps::PackageCompileStep.create(deployment_plan)
    end

    def with_updated_instances(deployment, job, &blk)
      job_manager = Errand::JobManager.new(deployment, job, logger)

      begin
        update_instances(job_manager)
        parent_id = add_event(job.instances.first.model.name)
        block_result = blk.call
        add_event(job.instances.first.model.name, parent_id, block_result.exit_code)
      rescue Exception => e
        add_event(job.instances.first.model.name, parent_id, nil, e)
        cleanup_vms_and_log_error(job_manager)
        raise
      else
        cleanup_vms(job_manager)
        return block_result.short_description(job.name)
      end
    end

    def cleanup_vms_and_log_error(job_manager)
      begin
        cleanup_vms(job_manager)
      rescue Exception => e
        logger.warn("Failed to delete vms: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}")
      end
    end

    def cleanup_vms(job_manager)
      if @keep_alive
        logger.info('Skipping vms deletion, keep-alive is set')
      else
        logger.info('Deleting vms')
        delete_vms(job_manager)
      end
    end

    def update_instances(job_manager)
      logger.info('Starting to create missing vms')
      job_manager.create_missing_vms

      logger.info('Starting to update job instances')
      job_manager.update_instances
    end

    def delete_vms(job_manager)
      @ignore_cancellation = true

      logger.info('Starting to delete job vms')
      job_manager.delete_vms

      @ignore_cancellation = false
    end

    private

    def add_event(instance_name, parent_id = nil, exit_code = nil, error = nil)
      context = exit_code.nil? ? {} : {exit_code: exit_code}
      event  = Config.current_job.event_manager.create_event(
        {
          parent_id:   parent_id,
          user:        Config.current_job.username,
          action:      'run',
          object_type: 'errand',
          object_name: @errand_name,
          task:        Config.current_job.task_id,
          deployment:  @deployment_name,
          instance:    instance_name,
          error:       error,
          context:     context,
        })
      event.id
    end
  end
end
