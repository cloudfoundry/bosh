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
      template = load_erb("rhel-ifcfg.erb")
      networks.each do |name, network| #network is used inside the template
        result = template.result(binding)
        Bosh::Agent::Util::update_file(result, "/etc/sysconfig/network-scripts/ifcfg-#{name}")
      end
      restart_networking_service
    end

    def restart_networking_service
      @logger.info("Restarting network")
      sh "service network restart"
    end
  end
end
