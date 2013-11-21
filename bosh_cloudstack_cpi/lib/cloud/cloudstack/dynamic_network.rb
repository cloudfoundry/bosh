# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

module Bosh::CloudStackCloud
  ##
  # Represents CloudStack dynamic network: where IaaS sets VM's IP
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
    # Configures CloudStack dynamic network. Right now it's a no-op,
    # as dynamic networks are completely managed by CloudStack
    #
    # @param [Fog::Compute::CloudStack] openstack Fog CloudStack Compute client
    # @param [Fog::Compute::CloudStack::Server] server CloudStack server to
    #   configure
    def configure(cloudstack, server)
    end

  end
end
