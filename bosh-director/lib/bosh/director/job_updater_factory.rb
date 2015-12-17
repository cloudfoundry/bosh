module Bosh::Director
  class JobUpdaterFactory
    def initialize(cloud, logger)
      @cloud = cloud
      @logger = logger
    end

    def new_job_updater(deployment_plan, job)
      links_resolver = DeploymentPlan::LinksResolver.new(deployment_plan, @logger)
      JobUpdater.new(deployment_plan, job, links_resolver, DiskManager.new(@cloud, @logger))
    end
  end
end
