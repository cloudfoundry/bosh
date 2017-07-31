module Bosh::Director
  class JobUpdaterFactory
    def initialize(logger, template_blob_cache)
      @logger = logger
      @template_blob_cache = template_blob_cache
    end

    def new_job_updater(ip_provider, job)
      JobUpdater.new(ip_provider, job, DiskManager.new(@logger), @template_blob_cache)
    end
  end
end
