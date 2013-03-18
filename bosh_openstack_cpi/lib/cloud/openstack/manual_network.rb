# Copyright (c) 2009-2013 VMware, Inc.

module Bosh::OpenStackCloud
  ##
  # Represents OpenStack manual network: where user sets VM's IP
  class ManualNetwork < Network

    ##
    # Creates a new manual network
    #
    # @param [String] name Network name
    # @param [Hash] spec Raw network spec
    def initialize(name, spec)
      super
    end

    ##
    # Returns the private IP address
    #
    # @return [String] ip address
    def private_ip
      @ip
    end

    ##
    # Configures OpenStack manual network. Right now it's a no-op,
    # as manual networks are completely managed by OpenStack
    #
    # @param [Fog::Compute::OpenStack] openstack Fog OpenStack Compute client
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server to
    #   configure
    def configure(openstack, server)
    end
  end
end