module Bosh::Director
  class DirectorDnsStateUpdater
    def initialize(dns_encoder)
      @powerdns_manager = PowerDnsManagerProvider.create
      @local_dns_manager = LocalDnsManager.create(Config.root_domain, Config.logger, dns_encoder)
    end

    def update_dns_for_instance(instance, dns_record_info)
      @powerdns_manager.update_dns_record_for_instance(instance, dns_record_info)
      @local_dns_manager.update_dns_record_for_instance(instance)

      @powerdns_manager.flush_dns_cache
    end
  end
end
