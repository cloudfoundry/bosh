# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AwsCloud
  ##
  # Represents AWS instance network config. EC2 instance has single NIC
  # with dynamic IP address and (optionally) a single elastic IP address
  # which instance itself is not aware of (vip). Thus we should perform
  # a number of sanity checks for the network spec provided by director
  # to make sure we don't apply something EC2 doesn't understand how to
  # deal with.
  #
  class NetworkConfigurator
    include Helpers

    ##
    # Creates new network spec
    #
    # @param [Hash] spec raw network spec passed by director
    # TODO Add network configuration examples
    def initialize(spec)
      unless spec.is_a?(Hash)
        raise ArgumentError, "Invalid spec, Hash expected, " \
                             "#{spec.class} provided"
      end

      @logger = Bosh::Clouds::Config.logger
      @dynamic_network = nil
      @vip_network = nil
      @security_groups = []

      spec.each_pair do |name, spec|
        network_type = spec["type"]

        case network_type
        when "dynamic"
          if @dynamic_network
            cloud_error("More than one dynamic network for `#{name}'")
          else
            @dynamic_network = DynamicNetwork.new(name, spec)
            @security_groups += extract_security_groups(spec)
          end
        when "vip"
          if @vip_network
            cloud_error("More than one vip network for `#{name}'")
          else
            @vip_network = VipNetwork.new(name, spec)
            @security_groups += extract_security_groups(spec)
          end
        else
          cloud_error("Invalid network type `#{network_type}': AWS CPI " \
                      "can only handle `dynamic' and `vip' network types")
        end

      end

      if @dynamic_network.nil?
        cloud_error("At least one dynamic network should be defined")
      end
    end

    # Applies network configuration to the vm
    # @param [AWS:EC2] ec2 instance EC2 client
    # @param [AWS::EC2::Instance] instance EC2 instance to configure
    def configure(ec2, instance)
      @dynamic_network.configure(ec2, instance)

      if @vip_network
        @vip_network.configure(ec2, instance)
      else
        # If there is no vip network we should disassociate any elastic IP
        # currently held by instance (as it might have had elastic IP before)
        elastic_ip = instance.elastic_ip

        if elastic_ip
          @logger.info("Disassociating elastic IP `#{elastic_ip}' " \
                       "from instance `#{instance.id}'")
          instance.disassociate_elastic_ip
        end
      end
    end

    ##
    # Returns the security groups for this network configuration, or
    # the default security groups if the configuration does not contain
    # security groups
    # @param [Array] default Default security groups
    # @return [Array] security groups
    def security_groups(default)
      if @security_groups.empty? && default
        default
      else
        @security_groups.sort
      end
    end

    private

    ##
    # Extracts the security groups from the network configuration
    # @param [Hash] network_spec Network specification
    # @raise [ArgumentError] if the security groups in the network_spec
    #   is not an Array
    def extract_security_groups(network_spec)
      if network_spec && network_spec["cloud_properties"]
        cloud_properties = network_spec["cloud_properties"]
        if cloud_properties && cloud_properties["security_groups"]
          unless cloud_properties["security_groups"].is_a?(Array)
            raise ArgumentError, "security groups must be an Array"
          end
          return cloud_properties["security_groups"]
        end
      end
      []
    end

  end

end
