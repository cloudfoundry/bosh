module Bosh::Director
  class JobUpdaterFactory
    def initialize(blobstore)
      @blobstore = blobstore
    end

    def new_job_updater(deployment_plan, job)
      job_renderer = JobRenderer.new(job, @blobstore)
      JobUpdater.new(deployment_plan, job, job_renderer)
    end
  end
end
