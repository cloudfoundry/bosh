# Copyright (c) 2009-2012 VMware, Inc.
require 'bosh_agent/platform/linux/network'
require 'bosh_agent/platform/rhel'

module Bosh::Agent
  class Platform::Rhel::Network < Platform::Linux::Network
    include Bosh::Exec

    def initialize
      super(File.join File.dirname(__FILE__), 'templates')
    end

    def write_network_interfaces
      template = ERB.new(load_erb("rhel-ifcfg.erb"), 0, '%<>-')
      @networks.each do |name, n|
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
      updated = Bosh::Agent::Util::update_file(result, '/etc/dhclient.conf')
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
