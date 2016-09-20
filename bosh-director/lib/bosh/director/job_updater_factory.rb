module Bosh::Director
  class JobUpdaterFactory
    def initialize(logger)
      @logger = logger
    end

    def new_job_updater(deployment_plan, job)
      JobUpdater.new(deployment_plan, job, DiskManager.new(@logger))
    end
  end
end
