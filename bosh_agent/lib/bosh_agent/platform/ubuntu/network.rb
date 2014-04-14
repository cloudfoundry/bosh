# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Platform::Ubuntu::Network < Platform::Linux::Network
    include Bosh::Exec

    def initialize(template_dir)
      super
    end

    def write_network_interfaces
      template = ERB.new(load_erb('interfaces.erb'), 0, '%<>-')
      result = template.result(binding)
      network_updated = Bosh::Agent::Util::update_file(result, '/etc/network/interfaces')
      if network_updated
        @logger.info('Updated networking')
        restart_networking_service
      end
    end

    def restart_networking_service
      # ubuntu 10.04 networking startup/upstart stuff is quite borked
      networks.each do |k, v|
        interface = v['interface']
        @logger.info("Restarting #{interface}")
        output = sh("service network-interface stop INTERFACE=#{interface}").output
        output += sh("service network-interface start INTERFACE=#{interface}").output
        @logger.info("Restarted networking: #{output}")
      end
    end

    def write_dhcp_conf
      template = ERB.new(load_erb('dhclient_conf.erb'), 0, '%<>-')
      result = template.result(binding)

      updated = nil

      if File.exists?('/etc/dhcp3/dhclient.conf')
        # Ubuntu 10.04 dhclient config located in /etc/dhcp3
        updated = Bosh::Agent::Util::update_file(result, '/etc/dhcp3/dhclient.conf')
      else
        updated = Bosh::Agent::Util::update_file(result, '/etc/dhcp/dhclient.conf')
      end

      if updated
        @logger.info('Updated dhclient.conf')
        restart_dhclient
      end
    end

    # Executing /sbin/dhclient starts another dhclient process, so it'll cause
    # a conflict with the existing system dhclient process and dns changes will
    # be flip floping each lease time. So in order to refresh dhclient
    # configuration we need to restart networking.
    #
    # If dhclient3 cannot release a lease because it collides with a network
    # restart (message "receive_packet failed on eth0: Network is down"
    # appears at /var/log/syslog) then the old dhclient3 process won't be
    # killed (see bug LP #38140), and there will be two dhclient3 process
    # running (and dns changes will be flip floping each lease time). So
    # before restarting the network, we first kill all dhclient3 process.
    def restart_dhclient
      sh('pkill dhclient', :on_error => :return)
      sh('/etc/init.d/networking restart', :on_error => :return)
    end

  end
end
