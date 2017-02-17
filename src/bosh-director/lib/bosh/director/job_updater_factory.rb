module Bosh::Director
  class JobUpdaterFactory
    def initialize(logger, job_renderer)
      @logger = logger
      @job_renderer = job_renderer
    end

    def new_job_updater(ip_provider, job)
      JobUpdater.new(ip_provider, job, DiskManager.new(@logger), @job_renderer)
    end
  end
end
