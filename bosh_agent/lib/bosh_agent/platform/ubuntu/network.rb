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
      template = load_erb("interfaces.erb")
      result = template.result(binding)
      network_updated = Bosh::Agent::Util::update_file(result, '/etc/network/interfaces')
      if network_updated
        @logger.info("Updated networking")
        restart_networking_service
      end
    end

    def restart_networking_service
      # ubuntu 10.04 networking startup/upstart stuff is quite borked
      networks.values.each do |v|
        interface = v['interface']
        @logger.info("Restarting #{interface}")
        output = sh("service network-interface stop INTERFACE=#{interface}").output
        output += sh("service network-interface start INTERFACE=#{interface}").output
        @logger.info("Restarted networking: #{output}")
      end
    end
  end
end
