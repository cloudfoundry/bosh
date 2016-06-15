require 'psych'

module Bosh::Director
  class Jobs::RunErrand < Jobs::BaseJob
    include LockHelper

    @queue = :normal

    def self.job_type
      :run_errand
    end

    def initialize(deployment_name, errand_name, keep_alive)
      @deployment_name = deployment_name
      @errand_name = errand_name
      @deployment_manager = Api::DeploymentManager.new
      @instance_manager = Api::InstanceManager.new
      @keep_alive = keep_alive
      blobstore = App.instance.blobstores.blobstore
      log_bundles_cleaner = LogBundlesCleaner.new(blobstore, 60 * 60 * 24 * 10, logger) # 10 days
      @logs_fetcher = LogsFetcher.new(@instance_manager, log_bundles_cleaner, logger)
    end

    def perform
      deployment_model = @deployment_manager.find_by_name(@deployment_name)
      deployment_manifest = Manifest.load_from_text(deployment_model.manifest, deployment_model.cloud_config, deployment_model.runtime_config)
      deployment_name = deployment_manifest.to_hash['name']
      with_deployment_lock(deployment_name) do
        deployment = nil
        job = nil

        event_log_stage = Config.event_log.begin_stage('Preparing deployment', 1)
        event_log_stage.advance_and_track('Preparing deployment') do
          planner_factory = DeploymentPlan::PlannerFactory.create(logger)
          deployment = planner_factory.create_from_manifest(deployment_manifest, deployment_model.cloud_config, deployment_model.runtime_config, {})
          deployment.bind_models
          job = deployment.job(@errand_name)

          if job.nil?
            raise JobNotFound, "Errand '#{@errand_name}' doesn't exist"
          end

          unless job.is_errand?
            raise RunErrandError,
              "Instance group '#{job.name}' is not an errand. To mark an instance group as an errand " +
                "set its lifecycle to 'errand' in the deployment manifest."
          end

          if job.instances.empty?
            raise InstanceNotFound, "Instance '#{@deployment_name}/#{@errand_name}/0' doesn't exist"
          end

          logger.info('Starting to prepare for deployment')
          job.bind_instances(deployment.ip_provider)

          JobRenderer.create.render_job_instances(job.needed_instance_plans)
        end

        deployment.compile_packages

        runner = Errand::Runner.new(job, result_file, @instance_manager, @logs_fetcher)

        cancel_blk = lambda {
          begin
            task_checkpoint
          rescue TaskCancelled => e
            runner.cancel
            raise e
          end
        }

        with_updated_instances(deployment, job) do
          logger.info('Starting to run errand')
          runner.run(&cancel_blk)
        end
      end
    end

    def task_cancelled?
      super unless @ignore_cancellation
    end

    private

    def with_updated_instances(deployment, job, &blk)
      job_manager = Errand::JobManager.new(deployment, job, Config.cloud, logger)

      begin
        update_instances(job_manager)
        block_result = blk.call
      rescue Exception
        cleanup_instances_and_log_error(job_manager)
        raise
      else
        cleanup_instances_and_raise_error(job_manager)
        return block_result
      end
    end

    def cleanup_instances_and_log_error(job_manager)
      begin
        cleanup_instances_and_raise_error(job_manager)
      rescue Exception => e
        logger.warn("Failed to delete instances: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}")
      end
    end

    def cleanup_instances_and_raise_error(job_manager)
      if @keep_alive
        logger.info('Skipping instances deletion, keep-alive is set')
      else
        logger.info('Deleting instances')
        delete_instances(job_manager)
      end
    end

    def update_instances(job_manager)
      logger.info('Starting to create missing vms')
      job_manager.create_missing_vms

      logger.info('Starting to update job instances')
      job_manager.update_instances
    end

    def delete_instances(job_manager)
      @ignore_cancellation = true

      logger.info('Starting to delete job instances')
      job_manager.delete_instances

      @ignore_cancellation = false
    end
  end
end
