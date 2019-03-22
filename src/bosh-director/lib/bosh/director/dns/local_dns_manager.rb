module Bosh::Director
  class LocalDnsManager
    def self.create(root_domain, logger)
      local_dns_records_repo = LocalDnsRecordsRepo.new(logger, root_domain)

      dns_publisher = BlobstoreDnsPublisher.new(
        lambda { App.instance.blobstores.blobstore },
        root_domain,
        AgentBroadcaster.new,
        logger)

      new(root_domain, local_dns_records_repo, dns_publisher, logger)
    end

    def initialize(root_domain, dns_repo, blobstore_publisher, logger)
      @root_domain = root_domain
      @dns_repo = dns_repo
      @blobstore_publisher = blobstore_publisher
      @logger = logger
    end

    def update_dns_record_for_instance(instance_plan)
      @dns_repo.update_for_instance(instance_plan)
      @blobstore_publisher.publish_and_send_to_instance(instance_plan.instance.model)
    end

    def delete_dns_for_instance(instance_model)
      @dns_repo.delete_for_instance(instance_model)
      @blobstore_publisher.publish_and_broadcast
    end
  end
end
