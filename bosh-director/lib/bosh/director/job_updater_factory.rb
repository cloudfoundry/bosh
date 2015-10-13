module Bosh::Director
  class JobUpdaterFactory
    def initialize(blobstore, cloud, logger)
      @blobstore = blobstore
      @cloud = cloud
      @logger = logger
    end

    def new_job_updater(deployment_plan, job)
      job_renderer = JobRenderer.new(job, @blobstore)
      links_resolver = DeploymentPlan::LinksResolver.new(deployment_plan, @logger)
      JobUpdater.new(deployment_plan, job, job_renderer, links_resolver, DiskManager.new(@cloud, @logger))
    end
  end
end
