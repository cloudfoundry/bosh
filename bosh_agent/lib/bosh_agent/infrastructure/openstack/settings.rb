# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Infrastructure::Openstack::Settings

    AUTHORIZED_KEYS = File.join("/home/", BOSH_APP_USER, ".ssh/authorized_keys")

    def load_settings
      setup_openssh_key
      Infrastructure::Openstack::Registry.get_settings
    end

    def authorized_keys
      AUTHORIZED_KEYS
    end

    def setup_openssh_key
      public_key = Infrastructure::Openstack::Registry.get_openssh_key
      if public_key.nil? || public_key.empty?
        return
      end
      FileUtils.mkdir_p(File.dirname(authorized_keys))
      FileUtils.chmod(0700, File.dirname(authorized_keys))
      FileUtils.chown(Bosh::Agent::BOSH_APP_USER, Bosh::Agent::BOSH_APP_GROUP, File.dirname(authorized_keys))
      File.open(authorized_keys, "w") { |f| f.write(public_key) }
      FileUtils.chown(Bosh::Agent::BOSH_APP_USER, Bosh::Agent::BOSH_APP_GROUP, authorized_keys)
      FileUtils.chmod(0644, authorized_keys)
    end

    def supported_network_types
      [NETWORK_TYPE[:vip], NETWORK_TYPE[:dhcp], NETWORK_TYPE[:manual]]
    end

    def get_network_settings(network_name, properties)
      require 'sigar'

      type = properties["type"]
      unless type && supported_network_types.include?(type)
        raise Bosh::Agent::StateError, "Unsupported network type '%s', valid types are: %s" % [type, supported_network_types.join(', ')]
      end

      # Nothing to do for "vip" networks
      return nil if type == NETWORK_TYPE[:vip]

      get_current_network_settings
    end

    def get_current_network_settings
      require 'sigar'

      sigar = Sigar.new
      net_info = sigar.net_info
      ifconfig = sigar.net_interface_config(net_info.default_gateway_interface)

      properties = {}
      properties["ip"] = ifconfig.address
      properties["netmask"] = ifconfig.netmask
      properties["dns"] = []
      properties["dns"] << net_info.primary_dns if net_info.primary_dns && !net_info.primary_dns.empty?
      properties["dns"] << net_info.secondary_dns if net_info.secondary_dns && !net_info.secondary_dns.empty?
      properties["gateway"] = net_info.default_gateway
      properties
    end

  end
end
