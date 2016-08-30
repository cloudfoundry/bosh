module Bosh::Director
  class JobUpdaterFactory
    def initialize(cloud, logger)
      @cloud = cloud
      @logger = logger
    end

    def new_job_updater(deployment_plan, job)
      JobUpdater.new(deployment_plan, job, DiskManager.new(@cloud, @logger))
    end
  end
end
