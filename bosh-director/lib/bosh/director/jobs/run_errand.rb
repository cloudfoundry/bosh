require 'psych'

module Bosh::Director
  class Jobs::RunErrand < Jobs::BaseJob
    include LockHelper

    @queue = :normal

    def self.job_type
      :run_errand
    end

    def initialize(deployment_name, errand_name)
      @deployment_name = deployment_name
      @errand_name = errand_name
      @deployment_manager = Api::DeploymentManager.new
      @instance_manager = Api::InstanceManager.new
      @blobstore = App.instance.blobstores.blobstore

      log_bundles_cleaner = LogBundlesCleaner.new(@blobstore, 60 * 60 * 24 * 10, logger) # 10 days
      @logs_fetcher = LogsFetcher.new(event_log, @instance_manager, log_bundles_cleaner, logger)
    end

    def perform
      deployment_model = @deployment_manager.find_by_name(@deployment_name)
      manifest = Psych.load(deployment_model.manifest)
      deployment = DeploymentPlan::Planner.parse(manifest, event_log, {})

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

      with_deployment_lock(deployment) do
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
      deployment_preparer = Errand::DeploymentPreparer.new(deployment, job, event_log, self)

      rp_updaters = [ResourcePoolUpdater.new(job.resource_pool)]
      rp_manager = DeploymentPlan::ResourcePools.new(event_log, rp_updaters)

      job_manager = Errand::JobManager.new(deployment, job, @blobstore, event_log)

      begin
        update_instances(deployment_preparer, rp_manager, job_manager)
        blk.call
      ensure
        delete_instances(rp_manager, job_manager)
      end
    end

    def update_instances(deployment_preparer, rp_manager, job_manager)
      logger.info('Starting to prepare for deployment')
      deployment_preparer.prepare_deployment
      deployment_preparer.prepare_job

      logger.info('Starting to update resource pool')
      rp_manager.update

      logger.info('Starting to update job instances')
      job_manager.update_instances
    end

    def delete_instances(rp_manager, job_manager)
      @ignore_cancellation = true

      logger.info('Starting to delete job instances')
      job_manager.delete_instances

      logger.info('Starting to refill resource pool')
      rp_manager.refill

      @ignore_cancellation = false
    end
  end
end
