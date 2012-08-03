# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AwsCloud
  ##
  #
  class DynamicNetwork < Network

    ##
    # Creates a new dynamic network
    #
    # @param [String] name Network name
    # @param [Hash] spec Raw network spec
    def initialize(name, spec)
      super
    end

    ##
    # Configures EC2 dynamic network. Right now it's a no-op,
    # as dynamic networks are completely managed by EC2
    # @param [AWS:EC2] instance EC2 client
    # @param [AWS::EC2::Instance] EC2 instance to configure
    def configure(ec2, instance)
      # If the security groups change, we need to recreate the VM
      # as you can't change the security group of a running instance,
      # and there isn't a clean way to propagate that all the way
      # back to the InstanceUpdater - the least ugly way is
      # throw/catch.
      current = instance.security_groups.collect {|sg| sg.name }
      configured = @cloud_properties["security_groups"].sort
      if !current.empty? && current != configured
        throw :recreate, true
      end
    end

  end
end


