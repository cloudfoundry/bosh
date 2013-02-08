# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Platform::Rhel::Network < Platform::Linux::Network
    def write_network_interfaces
      template = ERB.new(load_erb("rhel-ifcfg.erb"), 0, '%<>-')
      result = template.result(binding)
      network_updated = Bosh::Agent::Util::update_file(result, '/etc/sysconfig/network-scripts/ifcfg-eth0')

      if network_updated
        logger.info("Updated networking")
        restart_networking_service
      end
    end

    def restart_networking_service
      logger.info("Restarting network")
      Bosh::Exec.sh "service network restart"
    end
  end
end
