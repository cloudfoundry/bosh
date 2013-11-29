# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

module Bosh::CloudStackCloud
  ##
  # Represents CloudStack server network config. CloudStack server has single NIC
  # with a dynamic and (optionally) a single floating IP address which server
  # itself is not aware of (vip). Thus we should perform a number of sanity checks
  #  for the network spec provided by director to make sure we don't apply something
  # CloudStack doesn't understand how to deal with.
  class NetworkConfigurator
    include Helpers

    attr_reader :network_name

    ##
    # Creates new network spec
    #
    # @param [Hash] spec Raw network spec passed by director
    # @param Symbol zone_network_type CloudStack zone network type, :basic or :advanced
    def initialize(spec, zone_network_type = :advanced)
      unless spec.is_a?(Hash)
        raise ArgumentError, "Invalid spec, Hash expected, #{spec.class} provided"
      end

      @logger = Bosh::Clouds::Config.logger
      @network = nil
      @vip_network = nil
      @security_groups = []
      @network_name = nil
      @zone_network_type = zone_network_type

      spec.each_pair do |name, network_spec|
        network_type = network_spec["type"]

        case network_type
          when "dynamic"
            cloud_error("Must have exactly one dynamic network per instance") if @network
            @network = DynamicNetwork.new(name, network_spec)
            @security_groups += extract_security_groups(network_spec)
            @network_name = extract_network_name(network_spec)

          when "vip"
            cloud_error("More than one vip network") if @vip_network
            cloud_error("Vip network is not supported in a basic network") if @zone_network_type == :basic
            cloud_error("Vip network cannot have a network name") if extract_network_name(network_spec)
            @vip_network = VipNetwork.new(name, network_spec)
            @security_groups += extract_security_groups(network_spec)

          else
            cloud_error("Invalid network type `#{network_type}': CloudStack " \
                        "CPI can only handle `dynamic' or `vip' " \
                        "network types")
        end
      end

      cloud_error("At least one dynamic network should be defined") if @network.nil?
    end

    ##
    # Applies network configuration to the vm
    #
    # @param [Fog::Compute::CloudStack] compute Fog CloudStack Compute client
    # @param [Fog::Compute::CloudStack::Server] server CloudStack server to
    #   configure
    def configure(compute, server)
      @network.configure(compute, server)

      if @vip_network
        @vip_network.configure(compute, server)
      end
    end

    ##
    # Returns the security groups for this network configuration, or
    # the default security groups if the configuration does not contain
    # security groups
    #
    # @param [Array] default Default security groups
    # @return [Array] security groups
    def security_groups(default)
      if @security_groups.empty? && default
        default
      else
        @security_groups.sort
      end
    end

    ##
    # Returns the private IP address for this network configuration
    #
    # @return [String] private ip address
    def private_ip
      nil
    end

    ##
    # Returns the nics for this network configuration
    #
    # @return [Array] nics
    def nics
      nic = {}
      nic["network_name"] = @network_name if @network_name
      nic.any? ? [nic] : []
    end

    private

    ##
    # Extracts the security groups from the network configuration
    #
    # @param [Hash] network_spec Network specification
    # @return [Array] security groups
    # @raise [ArgumentError] if the security groups in the network_spec is not an Array
    def extract_security_groups(network_spec)
      if network_spec && network_spec["cloud_properties"]
        cloud_properties = network_spec["cloud_properties"]
        if cloud_properties && cloud_properties.has_key?("security_groups")
          unless cloud_properties["security_groups"].is_a?(Array)
            raise ArgumentError, "security groups must be an Array"
          end
          return cloud_properties["security_groups"]
        end
      end
      []
    end

    ##
    # Extracts the network ID from the network configuration
    #
    # @param [Hash] network_spec Network specification
    # @return [Hash] network ID
    def extract_network_name(network_spec)
      if network_spec && network_spec["cloud_properties"]
        cloud_properties = network_spec["cloud_properties"]
        if cloud_properties && cloud_properties.has_key?("network_name")
          return cloud_properties["network_name"]
        end
      end
      nil
    end

  end
end
