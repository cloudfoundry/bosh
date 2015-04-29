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
      @blobstore = App.instance.blobstores.blobstore
      @keep_alive = keep_alive
      log_bundles_cleaner = LogBundlesCleaner.new(@blobstore, 60 * 60 * 24 * 10, logger) # 10 days
      @logs_fetcher = LogsFetcher.new(event_log, @instance_manager, log_bundles_cleaner, logger)
    end

    def perform
      deployment_model = @deployment_manager.find_by_name(@deployment_name)
      deployment_manifest_hash = Psych.load(deployment_model.manifest)
      deployment_name = deployment_manifest_hash['name']
      with_deployment_lock(deployment_name) do
        cloud_config_model = deployment_model.cloud_config

        planner_factory = DeploymentPlan::PlannerFactory.create(event_log, logger)
        deployment = planner_factory.planner(deployment_manifest_hash, cloud_config_model, {})

        job = deployment.job(@errand_name)
        if job.nil?
          raise JobNotFound, "Errand `#{@errand_name}' doesn't exist"
        end

        unless job.can_run_as_errand?
          raise RunErrandError,
                "Job `#{job.name}' is not an errand. To mark a job as an errand " +
                  "set its lifecycle to 'errand' in the deployment manifest."
        end

        if job.instances.empty?
          raise InstanceNotFound, "Instance `#{@deployment_name}/#{@errand_name}/0' doesn't exist"
        end

        runner = Errand::Runner.new(job, result_file, @instance_manager, event_log, @logs_fetcher)

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
      rp_updaters = [ResourcePoolUpdater.new(job.resource_pool)]
      resource_pools = DeploymentPlan::ResourcePools.new(event_log, rp_updaters)

      job_manager = Errand::JobManager.new(deployment, job, @blobstore, event_log, logger)

      begin
        update_instances(resource_pools, job_manager)
        blk.call
      ensure
        if @keep_alive
          logger.info('Skipping instances deletion, keep-alive is set')
        else
          logger.info('Deleting instances')
          delete_instances(resource_pools, job_manager)
        end
      end
    end

    def update_instances(resource_pools, job_manager)
      logger.info('Starting to prepare for deployment')
      job_manager.prepare

      logger.info('Starting to update resource pool')
      resource_pools.update

      logger.info('Starting to update job instances')
      job_manager.update_instances
    end

    def delete_instances(resource_pools, job_manager)
      @ignore_cancellation = true

      logger.info('Starting to delete job instances')
      job_manager.delete_instances

      logger.info('Starting to refill resource pool')
      resource_pools.refill

      @ignore_cancellation = false
    end
  end
end
