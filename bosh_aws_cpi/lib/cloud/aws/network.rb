# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AwsCloud
  ##
  #
  class Network
    include Helpers

    ##
    # Creates a new network
    #
    # @param [String] name Network name
    # @param [Hash] spec Raw network spec
    def initialize(name, spec)
      unless spec.is_a?(Hash)
        raise ArgumentError, "Invalid spec, Hash expected, " \
                             "#{spec.class} provided"
      end

      @logger = Bosh::Clouds::Config.logger

      @name = name
      @ip = spec["ip"]
      @cloud_properties = spec["cloud_properties"]
    end

    ##
    # Configures given instance
    #
    # @param [AWS:EC2] instance EC2 client
    # @param [AWS::EC2::Instance] EC2 instance to configure
    def configure(ec2, instance)
      cloud_error("`configure' not implemented by #{self.class}")
    end

  end
end
