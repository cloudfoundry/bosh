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

    attr_reader :vip_network, :network

    ##
    # Creates new network spec
    #
    # @param [Hash] spec raw network spec passed by director
    def initialize(spec)
      unless spec.is_a?(Hash)
        raise ArgumentError, "Invalid spec, Hash expected, " \
                             "#{spec.class} provided"
      end

      @logger = Bosh::Clouds::Config.logger
      @network = nil
      @vip_network = nil

      spec.each_pair do |name, network_spec|
        network_type = network_spec["type"] || "manual"

        case network_type
          when "dynamic"
            cloud_error("Must have exactly one dynamic or manual network per instance") if @network
            @network = DynamicNetwork.new(name, network_spec)

          when "manual"
            cloud_error("Must have exactly one dynamic or manual network per instance") if @network
            @network = ManualNetwork.new(name, network_spec)

          when "vip"
            cloud_error("More than one vip network for '#{name}'") if @vip_network
            @vip_network = VipNetwork.new(name, network_spec)

          else
            cloud_error("Invalid network type '#{network_type}' for AWS, " \
                        "can only handle 'dynamic', 'vip', or 'manual' network types")
        end
      end

      unless @network
        cloud_error("Exactly one dynamic or manual network must be defined")
      end
    end

    def subnet
      @network.subnet
    end

    def private_ip
      vpc? ? @network.private_ip : nil
    end

    def vpc?
      @network.is_a? ManualNetwork
    end

    # Applies network configuration to the vm
    # @param [AWS:EC2] ec2 instance EC2 client
    # @param [AWS::EC2::Instance] instance EC2 instance to configure
    def configure(ec2, instance)
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
  end
end
