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

      runner = Errand::Runner.new(job, result_file, @instance_manager, event_log)

      with_updated_instances(deployment, job) do
        logger.info('Starting to run errand')
        runner.run
      end
    end

    private

    def with_updated_instances(deployment, job, &blk)
      result = nil

      with_deployment_lock(deployment) do
        logger.info('Starting to prepare for deployment')
        prepare_deployment(deployment, job)

        logger.info('Starting to update resource pool')
        rp_manager = update_resource_pool(job)

        logger.info('Starting to update job instances')
        job_manager = update_instances(deployment, job)

        result = blk.call

        logger.info('Starting to delete job instances')
        job_manager.delete_instances

        logger.info('Starting to refill resource pool')
        rp_manager.refill
      end

      result
    end

    def prepare_deployment(deployment, job)
      deployment_preparer = Errand::DeploymentPreparer.new(
        deployment, job, event_log, self)

      deployment_preparer.prepare_deployment
      deployment_preparer.prepare_job
    end

    def update_resource_pool(job)
      rp_updaters = [ResourcePoolUpdater.new(job.resource_pool)]
      rp_manager = DeploymentPlan::ResourcePools.new(event_log, rp_updaters)

      rp_manager.update
      rp_manager
    end

    def update_instances(deployment, job)
      job_manager = Errand::JobManager.new(
        deployment, job, @blobstore, event_log)

      job_manager.update_instances
      job_manager
    end
  end
end
