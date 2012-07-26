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
    def read_settings(server_id)
      get_server(server_id).settings
    end

    def delete_settings(server_id)
      get_server(server_id).destroy
    end

    private

    def get_server(server_id)
      server = Models::OpenstackServer[:server_id => server_id]

      if server.nil?
        raise ServerNotFound, "Can't find server `#{server_id}'"
      end

      server
    end

  end

end