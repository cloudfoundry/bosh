# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::OpenstackRegistry

  class ServerManager

    def initialize
      @logger = Bosh::OpenstackRegistry.logger
      @openstack = Bosh::OpenstackRegistry.openstack
    end

    ##
    # Updates server settings
    # @param [String] server_id OpenStack server id (server record
    #        will be created in DB if it doesn't already exist)
    # @param [String] settings New settings for the server
    def update_settings(server_id, settings)
      params = {
        :server_id => server_id
      }

      server = Models::OpenstackServer[params] || Models::OpenstackServer.new(params)
      server.settings = settings
      server.save
    end

    ##
    # Reads server settings
    # @param [String] server_id OpenStack server id
    # @param [optional, String] remote_ip If this IP is provided, check will
    #   be performed to see if the server id actually has this IP address
    #   according to OpenStack.
    def read_settings(server_id, remote_ip = nil)
      check_instance_ips(remote_ip, server_id) if remote_ip

      get_server(server_id).settings
    end

    def delete_settings(server_id)
      get_server(server_id).destroy
    end

    private

    def check_instance_ips(ip, server_id)
      return if ip == "127.0.0.1"
      actual_ips = server_ips(server_id)
      unless actual_ips.include?(ip)
        raise ServerError, "Server IP mismatch, expected IP is " \
                           "`%s', actual IP(s): `%s'" %
                           [ ip, actual_ips.join(", ") ]
      end
    end

    def get_server(server_id)
      server = Models::OpenstackServer[:server_id => server_id]

      if server.nil?
        raise ServerNotFound, "Can't find server `#{server_id}'"
      end

      server
    end

    # Get the list of IPs belonging to this server
    def server_ips(server_id)
      server = @openstack.servers.get(server_id)
      if server
        ips = []
        server.addresses.each do |network, addresses|
          addresses.each do |addr|
            ips.push(addr.kind_of?(Hash) ? addr["addr"] : addr)
          end
        end
        ips
      else
        raise ServerNotFound, "Server `#{server_id}' not found"
      end
    end

  end

end