module Bosh::Director
  class JobUpdaterFactory
    def initialize(blobstore, logger)
      @blobstore = blobstore
      @logger = logger
    end

    def new_job_updater(deployment_plan, job)
      job_renderer = JobRenderer.new(job, @blobstore)
      links_resolver = LinksResolver.new(deployment_plan, @logger)
      JobUpdater.new(deployment_plan, job, job_renderer, links_resolver)
    end
  end
end
