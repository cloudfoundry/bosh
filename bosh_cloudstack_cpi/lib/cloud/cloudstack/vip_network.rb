# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.
# Copyright (c) 2012 ZJU Cloud Computing, Inc.

module Bosh::CloudStackCloud
  ##
  #
  class VipNetwork < Bosh::CloudStackCloud::Network

    ##
    # Creates a new vip network
    #
    # @param [String] name Network name
    # @param [Hash] spec Raw network spec
    def initialize(name, spec)
      super
    end

    ##
    # Configures vip network
    #
    # @param [Fog::Compute::cloudstack] cloudstack Fog cloudstack Compute client
    # @param [Fog::Compute::cloudstack::Server] server cloudstack server to configure
    def configure(cloudstack, server)
      if @ip.nil?
        cloud_error("No IP provided for vip network `#{@name}'")
      end

      @logger.info("Associating server `#{server.id}' " \
        "with floating IP `#{@ip}'")

      # Check if the cloudstack floating IP is allocated. If true, check
      # if it is associated to any server, so we can disassociate it
      # before associating it to the new server.
      address = cloudstack.ipaddresses.find { |a| a.ip_address == @ip }
      
      unless address
        cloud_error("No IP `#{@ip}' found in vip network `#{@name}'")
      end
      
      if address.virtual_machine_id
        static_nat_params = {
          :ip_address_id => address.id,
        }

        static_nat = cloudstack.nats.new(static_nat_params)
        @logger.info("The floating IP #{@ip} has been associated to server `#{address.virtual_machine_id}', " \
                     "so disassociate it first")
        static_nat_job = static_nat.disable
        cost_time = static_nat_job.wait_for { ready? }
        @logger.info("The floating IP #{@ip} is disassociated after #{cost_time[:duration]}s")
      end


      @logger.info("Now associate this IP to server `#{server.id}'")
      static_nat_params = {
        :ip_address_id => address.id,
        :virtual_machine_id => server.id,
        :network_id => server.nics.first["networkid"],
      }
      static_nat = cloudstack.nats.new(static_nat_params)
      static_nat.enable
    end
  end
end
