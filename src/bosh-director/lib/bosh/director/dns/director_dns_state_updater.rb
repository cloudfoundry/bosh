module Bosh::Director
  class DirectorDnsStateUpdater
    def initialize
      @dns_manager = DnsManagerProvider.create
      @local_dns_repo = LocalDnsRepo.new(Config.logger, Config.root_domain)
      @dns_publisher = BlobstoreDnsPublisher.new(
        lambda { App.instance.blobstores.blobstore },
        Config.root_domain,
        AgentBroadcaster.new,
        Config.logger
      )
    end

    def update_dns_for_instance(instance, dns_record_info)
      @dns_manager.update_dns_record_for_instance(instance, dns_record_info)
      @local_dns_repo.update_for_instance(instance)

      @dns_manager.flush_dns_cache
      @dns_publisher.publish_and_broadcast
    end

    def publish_dns_records
      @dns_publisher.publish_and_broadcast
    end
  end
end
