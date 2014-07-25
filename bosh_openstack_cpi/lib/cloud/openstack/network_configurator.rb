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
      @networks = []
      @vip_network = nil
      @security_groups = []
      @net_ids = []
      @dynamic_network = nil

      spec.each_pair do |name, network_spec|
        initialize_network(name, network_spec)
      end

      cloud_error("At least one dynamic or manual network should be defined") if @networks.empty?
    end


    ##
    # Setup network configuration for one network spec.
    #
    # @param [String] network spec name
    # @param [Hash] network spec
    #   configure
    def initialize_network(name, network_spec)
      network_type = network_spec["type"] || "manual"

      case network_type
        when "dynamic"
          net_id = extract_net_id(network_spec)
          cloud_error("Only one dynamic network per instance should be defined") if @dynamic_network
          cloud_error("Dynamic network with id #{net_id} is already defined") if @net_ids.include?(net_id)
          network = DynamicNetwork.new(name, network_spec)
          @security_groups += extract_security_groups(network_spec)
          net_info = {}
          net_info["network"] = network
          net_info["net_id"] = net_id
          @networks << net_info
          @net_ids << net_id
          @dynamic_network = network

        when "manual"
          net_id = extract_net_id(network_spec)
          cloud_error("Manual network must have net_id") if net_id.nil?
          cloud_error("Manual network with id #{net_id} is already defined") if @net_ids.include?(net_id)
          network = ManualNetwork.new(name, network_spec)
          @security_groups += extract_security_groups(network_spec)
          net_info = {}
          net_info["network"] = network
          net_info["net_id"] = net_id
          @networks << net_info
          @net_ids << net_id

        when "vip"
          cloud_error("Only one VIP network per instance should be defined") if @vip_network
          @vip_network = VipNetwork.new(name, network_spec)
          @security_groups += extract_security_groups(network_spec)

        else
          cloud_error("Invalid network type `#{network_type}': OpenStack " \
                      "CPI can only handle `dynamic', 'manual' or `vip' " \
                      "network types")
      end
    end

    ##
    # Applies network configuration to the vm
    #
    # @param [Fog::Compute::OpenStack] openstack Fog OpenStack Compute client
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server to
    #   configure
    def configure(openstack, server)
      @networks.each do |network_info|
        network = network_info["network"]
        network.configure(openstack, server)
      end

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
      @networks.each do |network_info|
        network = network_info["network"]
        if network.is_a?(ManualNetwork)
          return network.private_ip
        end
      end
      return nil
    end

    ##
    # Returns the nics for this network configuration
    #
    # @return [Array] nics
    def nics
      nics_all = []
      @networks.each do |network_info|
        nic = {}
        net_id = network_info["net_id"]
        network = network_info["network"]
        nic["net_id"] = net_id if net_id
        nic["v4_fixed_ip"] = network.private_ip if network.is_a? ManualNetwork
        if nic.any?
          nics_all << nic
        end
      end
      @logger.info("nics_all `#{nics_all}'")
      return nics_all
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
