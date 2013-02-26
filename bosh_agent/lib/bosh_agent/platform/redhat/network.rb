# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Platform::Redhat::Network < Platform::Linux::Network

    def write_network_interfaces
      template = ERB.new(load_erb("redhat-ifcfg.erb"), 0, '%<>-')
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

    def write_dhcp_conf
      template = ERB.new(load_erb("dhclient_conf.erb"), 0, '%<>-')
      result = template.result(binding)
      updated = Bosh::Agent::Util::update_file(result, '/etc/dhclient.conf')
      if updated
        logger.info("Updated dhclient.conf")
        restart_dhclient
      end
    end

    def restart_dhclient
      logger.info("Restarting network to restart dhclient")
      Bosh::Exec.sh "service network restart"
    end
  end
end
