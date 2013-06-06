# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

module Bosh::OpenStackCloud
  ##
  # Represents OpenStack server network config. OpenStack server has single NIC
  # with a dynamic or manual IP's address and (optionally) a single floating
  # IP address which server itself is not aware of (vip). Thus we should
  # perform a number of sanity checks for the network spec provided by director
  # to make sure we don't apply something OpenStack doesn't understand how to
  # deal with.
  class NetworkConfigurator
    include Helpers

    ##
    # Creates new network spec
    #
    # @param [Hash] spec Raw network spec passed by director
    def initialize(spec)
      unless spec.is_a?(Hash)
        raise ArgumentError, "Invalid spec, Hash expected, #{spec.class} provided"
      end

      @logger = Bosh::Clouds::Config.logger
      @network = nil
      @vip_network = nil
      @security_groups = []
      @net_id = nil

      spec.each_pair do |name, network_spec|
        network_type = network_spec["type"] || "manual"

        case network_type
          when "dynamic"
            cloud_error("Must have exactly one dynamic or manual network per instance") if @network
            @network = DynamicNetwork.new(name, network_spec)
            @security_groups += extract_security_groups(network_spec)
            @net_id = extract_net_id(network_spec)

          when "manual"
            cloud_error("Must have exactly one dynamic or manual network per instance") if @network
            @network = ManualNetwork.new(name, network_spec)
            @security_groups += extract_security_groups(network_spec)
            @net_id = extract_net_id(network_spec)
            cloud_error("Manual network must have net_id") if @net_id.nil?

          when "vip"
            cloud_error("More than one vip network") if @vip_network
            @vip_network = VipNetwork.new(name, network_spec)
            @security_groups += extract_security_groups(network_spec)

          else
            cloud_error("Invalid network type `#{network_type}': OpenStack " \
                        "CPI can only handle `dynamic', 'manual' or `vip' " \
                        "network types")
        end
      end

      cloud_error("At least one dynamic or manual network should be defined") if @network.nil?
    end

    ##
    # Applies network configuration to the vm
    #
    # @param [Fog::Compute::OpenStack] openstack Fog OpenStack Compute client
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server to
    #   configure
    def configure(openstack, server)
      @network.configure(openstack, server)

      if @vip_network
        @vip_network.configure(openstack, server)
      else
        # If there is no vip network we should disassociate any floating IP
        # currently held by server (as it might have had floating IP before)
        with_openstack do
          addresses = openstack.addresses
          addresses.each do |address|
            if address.instance_id == server.id
              @logger.info("Disassociating floating IP `#{address.ip}' " \
                           "from server `#{server.id}'")
              address.server = nil
            end
          end
        end
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
      @network.is_a?(ManualNetwork) ? @network.private_ip : nil   
    end

    ##
    # Returns the nics for this network configuration
    #
    # @return [Array] nics
    def nics
      nic = {}
      nic["net_id"] = @net_id if @net_id
      nic["v4_fixed_ip"] = @network.private_ip if @network.is_a? ManualNetwork
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
    def extract_net_id(network_spec)
      if network_spec && network_spec["cloud_properties"]
        cloud_properties = network_spec["cloud_properties"]
        if cloud_properties && cloud_properties.has_key?("net_id")
          return cloud_properties["net_id"]
        end
      end
      nil
    end

  end
end