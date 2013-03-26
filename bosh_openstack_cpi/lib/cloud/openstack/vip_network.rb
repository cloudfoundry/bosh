# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

module Bosh::OpenStackCloud
  ##
  # Represents OpenStack vip network: where users sets VM's IP (floating IP's
  # in OpenStack)
  class VipNetwork < Network

    ##
    # Creates a new vip network
    #
    # @param [String] name Network name
    # @param [Hash] spec Raw network spec
    def initialize(name, spec)
      super
    end

    ##
    # Configures OpenStack vip network
    #
    # @param [Fog::Compute::OpenStack] openstack Fog OpenStack Compute client
    # @param [Fog::Compute::OpenStack::Server] server OpenStack server to
    #   configure
    def configure(openstack, server)
      if @ip.nil?
        cloud_error("No IP provided for vip network `#{@name}'")
      end

      # Check if the OpenStack floating IP is allocated. If true, disassociate
      # it from any server before associating it to the new server
      with_openstack do
        address = openstack.addresses.find { |a| a.ip == @ip }
        if address
          unless address.instance_id.nil?
            @logger.info("Disassociating floating IP `#{@ip}' " \
                         "from server `#{address.instance_id}'")
            address.server = nil
          end

          @logger.info("Associating server `#{server.id}' " \
                       "with floating IP `#{@ip}'")
          address.server = server
        else
          cloud_error("Floating IP #{@ip} not allocated")
        end
      end
    end

  end
end