module Bosh::Director
  class DirectorDnsStateUpdater
    def initialize
      @local_dns_manager = LocalDnsManager.create(Config.root_domain, Config.logger)
    end

    def update_dns_for_instance(instance_plan, dns_record_info)
      @local_dns_manager.update_dns_record_for_instance(instance_plan)
    end
  end
end
