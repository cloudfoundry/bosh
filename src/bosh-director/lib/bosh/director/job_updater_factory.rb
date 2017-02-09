module Bosh::Director
  class JobUpdaterFactory
    def initialize(logger)
      @logger = logger
    end

    def new_job_updater(ip_provider, job)
      JobUpdater.new(ip_provider, job, DiskManager.new(@logger))
    end
  end
end
