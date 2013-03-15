# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent

  NETWORK_TYPE  = { :vip => 'vip',   :dhcp => 'dynamic', :manual => 'manual' }
  DISK_TYPE     = { :scsi => 'scsi', :other => 'nil' }

  class UnknownInfrastructure < StandardError; end

  class Infrastructure

    def initialize(infrastructure_name)
      @name = infrastructure_name
      # TODO: add to loadpath?
      infrastructure = File.join(File.dirname(__FILE__), 'infrastructure', "#{infrastructure_name}.rb")

      if File.exist?(infrastructure)
        load infrastructure
      else
        raise UnknownInfrastructure, "infrastructure '#{infrastructure_name}' not found"
      end
    end

    def infrastructure
      Infrastructure.const_get(@name.capitalize).new
    end

    def to_s
      @name
    end


    class Settings
      require 'sigar'

      def load_settings
        raise Bosh::Agent::UnimplementedMethod.new
      end

      def get_network_settings(network_name, properties)
        type = network_type(properties) || NETWORK_TYPE[:manual]
        unless type && supported_network_types.include?(type)
          raise Bosh::Agent::StateError, "Unsupported network type '%s', valid types are: %s" % [type, supported_network_types.join(', ')]
        end

        # Nothing to do for "vip" networks
        return nil if type == NETWORK_TYPE[:vip]

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

      protected
      def supported_network_types
        [NETWORK_TYPE[:vip], NETWORK_TYPE[:dhcp], NETWORK_TYPE[:manual]]
      end

      def network_type(properties)
        type = properties["type"]
        unless type && supported_network_types.include?(type)
          raise Bosh::Agent::StateError, "Unsupported network type '%s', valid types are: %s" % [type, supported_network_types.join(', ')]
        end
        type
      end
    end

  end

end
