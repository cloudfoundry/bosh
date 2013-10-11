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
      network = cloudstack.networks.find { |n| n.name == @name}
      network_id = network.id
      address = cloudstack.ipaddresses.find { |a| a.ip_address == @ip && a.associated_network_id == network_id}
      if address
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
          @logger.info("Configuring firewall rules for IP #{@ip}")

          configure_firewall(cloudstack, address)

          @logger.info("Now associate this IP to server `#{server.id}'")

          static_nat.virtual_machine_id = server.id
          static_nat.enable
        else
          @logger.info("Configuring firewall rules for IP #{@ip}")

          configure_firewall(cloudstack, address)

          @logger.info("Now associate this IP to server `#{server.id}'")
          static_nat_params = {
              :ip_address_id => address.id,
              :virtual_machine_id => server.id
          }
          static_nat = cloudstack.nats.new(static_nat_params)
          static_nat.enable
        end

      else
        ip_array = @ip.split(".")
        gateway = ip_array[0] + "." + ip_array[1] + "." + ip_array[2] + "." + "254"  #need to config again
        vlan_params = {
            :zone_id => server.zone_id,
            :gateway => gateway,
            :netmask => "255.255.255.0",
            :start_ip => @ip,
            :end_ip => @ip,
            :vlan => "untagged"
        }
        vlan = cloudstack.vlans.new(vlan_params)
        vlan.create_vlan_ip_range
        ip_address_params = {
            :network_id => network_id
        }

        address = cloudstack.ipaddresses.new(ip_address_params)
        address_job = address.associate
        address_job.wait_for { ready? }

        @logger.info("Configuring firewall rules for IP #{@ip}")

        configure_firewall(cloudstack, address)

        @logger.info("Now associate this IP to server `#{server.id}'")

        static_nat_params = {
            :ip_address_id => address.id,
            :virtual_machine_id => server.id
        }
        static_nat = cloudstack.nats.new(static_nat_params)
        static_nat.enable

      end

    end

    ##
    # Configures firewall rules of an IP address
    #
    # @param [Fog::Compute::cloudstack] cloudstack Fog cloudstack Compute client
    # @param [Fog::Compute::cloudstack::Ipaddress] address the ip address to configure
    def configure_firewall(cloudstack, address)
      #configure tcp rules
      configure_firewall_by_protocol(cloudstack, address ,"tcp")
      #configure udp rules
      configure_firewall_by_protocol(cloudstack, address ,"udp")
      #configure icmp rules
      configure_firewall_by_protocol(cloudstack, address ,"icmp")

    end

    def configure_firewall_by_protocol(cloudstack, address, protocol)
      cidr_list = "0.0.0.0/0"
      start_port = 1
      end_port = 65535
      icmp_type = -1
      icmp_code = -1

      firewall_params = {
          :ip_address_id => address.id,
          :protocol => protocol,
          :cidr_list => cidr_list
      }

      case protocol
        when "tcp", "udp"
          firewall_params.merge!('startport' => start_port)
          firewall_params.merge!('endport' => end_port)
        when "icmp"
          firewall_params.merge!('icmptype' => icmp_type)
          firewall_params.merge!('icmpcode' => icmp_code)
      end

      firewall = cloudstack.firewalls.new(firewall_params)
      firewall_job = firewall.create_firewall_rule
      #firewall_job.wait_for { ready? }

    end

  end
end
