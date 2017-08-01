module Bosh::Director
  class LocalDnsManager
    def self.create(root_domain, logger)
      local_dns_repo = LocalDnsRepo.new(logger, root_domain)

      dns_publisher = BlobstoreDnsPublisher.new(
        lambda { App.instance.blobstores.blobstore },
        root_domain,
        AgentBroadcaster.new,
        LocalDnsEncoderManager.create_dns_encoder,
        logger)

      new(root_domain, local_dns_repo, dns_publisher, logger)
    end

    def initialize(root_domain, dns_repo, blobstore_publisher, logger)
      @root_domain = root_domain
      @dns_repo = dns_repo
      @blobstore_publisher = blobstore_publisher
      @logger = logger
    end

    def update_dns_record_for_instance(instance_model)
      @dns_repo.update_for_instance(instance_model)
      @blobstore_publisher.publish_and_broadcast
    end

    def delete_dns_for_instance(instance_model)
      @dns_repo.delete_for_instance(instance_model)
      @blobstore_publisher.publish_and_broadcast
    end
  end
end
