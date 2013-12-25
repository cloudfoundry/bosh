module Bosh::Agent
  class Platform::Centos::Network < Platform::Linux::Network
    include Bosh::Exec

    def initialize(template_dir)
      super
    end

    def write_network_interfaces
      template = ERB.new(load_erb("centos-ifcfg.erb"), 0, '%<>-')
      networks.each do |name, network|
        result = template.result(binding)
        Bosh::Agent::Util::update_file(result, "/etc/sysconfig/network-scripts/ifcfg-#{name}")
      end
      restart_networking_service
    end

    def restart_networking_service
      @logger.info("Restarting network")
      sh "service network restart"
    end

    def write_dhcp_conf
      template = ERB.new(load_erb("dhclient_conf.erb"), 0, '%<>-')
      result = template.result(binding)
      updated = Bosh::Agent::Util::update_file(result, '/etc/dhcp/dhclient.conf')
      if updated
        @logger.info("Updated dhclient.conf")
        restart_dhclient
      end
    end

    def restart_dhclient
      @logger.info("Restarting network to restart dhclient")
      sh "service network restart"
    end

  end
end
