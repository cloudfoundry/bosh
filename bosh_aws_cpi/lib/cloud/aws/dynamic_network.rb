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
    # @param [AWS:EC2] ec2 instance EC2 client
    # @param [AWS::EC2::Instance] instance EC2 instance to configure
    def configure(ec2, instance)
    end

  end
end


