module Bosh::Director
  class InstanceGroupUpdaterFactory
    def initialize(logger, template_blob_cache, dns_encoder)
      @logger = logger
      @template_blob_cache = template_blob_cache
      @dns_encoder = dns_encoder
    end

    def new_instance_group_updater(ip_provider, job)
      InstanceGroupUpdater.new(ip_provider, job, DiskManager.new(@logger), @template_blob_cache, @dns_encoder)
    end
  end
end
