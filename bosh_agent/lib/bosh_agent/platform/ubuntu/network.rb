# Copyright (c) 2009-2012 VMware, Inc.
require 'bosh_agent/platform/ubuntu'
require 'bosh_agent/platform/linux/network'

module Bosh::Agent
  class Platform::Ubuntu::Network < Platform::Linux::Network
    include Bosh::Exec

    def initialize
      super(File.join File.dirname(__FILE__), 'templates')
    end

    def write_network_interfaces
      template = ERB.new(load_erb("interfaces.erb"), 0, '%<>-')
      result = template.result(binding)
      network_updated = Bosh::Agent::Util::update_file(result, '/etc/network/interfaces')
      if network_updated
        @logger.info("Updated networking")
        restart_networking_service
      end
    end

    def restart_networking_service
      # ubuntu 10.04 networking startup/upstart stuff is quite borked
      @networks.each do |k, v|
        interface = v['interface']
        @logger.info("Restarting #{interface}")
        output = sh("service network-interface stop INTERFACE=#{interface}").output
        output += sh("service network-interface start INTERFACE=#{interface}").output
        @logger.info("Restarted networking: #{output}")
      end
    end

    def write_dhcp_conf
      template = ERB.new(load_erb("dhclient_conf.erb"), 0, '%<>-')
      result = template.result(binding)
      updated = Bosh::Agent::Util::update_file(result, '/etc/dhcp3/dhclient.conf')
      if updated
        @logger.info("Updated dhclient.conf")
        restart_dhclient
      end
    end

    def restart_dhclient
      sh "/etc/init.d/networking restart"
    end

  end
end
