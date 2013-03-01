# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

module Bosh::OpenStackCloud
  ##
  # Represents OpenStack Registry Client. It performs CRUD operations against
  # the OpenStack Registry.
  #
  # Settings example:
  # settings = {
  #   "vm" => {
  #     "name" => server_name
  #   },
  #   "agent_id" => agent_id,
  #   "networks" => network_spec,
  #   "disks" => {
  #     "system" => "/dev/vda",
  #     "ephemeral" => "/dev/vdb",
  #     "persistent" => {"volume_id" => device_name}
  #   }
  # }
  class RegistryClient
    include Helpers

    attr_reader :endpoint
    attr_reader :user
    attr_reader :password

    ##
    # Creates a new Registry client
    #
    # @param [String] endpoint Registry endpoint URL
    # @param [String] user Registry user
    # @param [String] password Registry password
    def initialize(endpoint, user, password)
      @endpoint = endpoint

      unless @endpoint =~ /^http:\/\//
        @endpoint = "http://#{@endpoint}"
      end

      @user = user
      @password = password
      auth = Base64.encode64("#{@user}:#{@password}").gsub("\n", "")

      @headers = {
        "Accept" => "application/json",
        "Authorization" => "Basic #{auth}"
      }

      @client = HTTPClient.new
    end

    ##
    # Update server settings in the registry
    #
    # @param [String] server_id OpenStack server id
    # @param [Hash] settings New agent settings
    # @return [Boolean]
    def update_settings(server_id, settings)
      unless settings.is_a?(Hash)
        raise ArgumentError, "Invalid settings format, " \
                             "Hash expected, #{settings.class} given"
      end

      payload = Yajl::Encoder.encode(settings)
      url = "#{@endpoint}/servers/#{server_id}/settings"

      response = @client.put(url, {:body => payload, :header => @headers})
      if response.status != 200
        cloud_error("Cannot update settings for `#{server_id}', " \
                    "got HTTP #{response.status}")
      end

      true
    end

    ##
    # Read server settings from the registry
    #
    # @param [String] server_id OpenStack server id
    # @return [Hash] Agent settings
    def read_settings(server_id)
      url = "#{@endpoint}/servers/#{server_id}/settings"

      response = @client.get(url, {:header => @headers})
      if response.status != 200
        cloud_error("Cannot read settings for `#{server_id}', " \
                    "got HTTP #{response.status}")
      end

      body = Yajl::Parser.parse(response.body)
      unless body.is_a?(Hash)
        cloud_error("Invalid registry response, Hash expected, " \
                    "got #{body.class}: #{body}")
      end

      settings = Yajl::Parser.parse(body["settings"])
      unless settings.is_a?(Hash)
        cloud_error("Invalid settings format, " \
                    "Hash expected, got #{settings.class}: " \
                    "#{settings}")
      end

      settings
    rescue Yajl::ParseError
      cloud_error("Cannot parse settings for `#{server_id}'")
    end

    ##
    # Delete server settings from the registry
    #
    # @param [String] server_id OpenStack server id
    # @return [Boolean]
    def delete_settings(server_id)
      url = "#{@endpoint}/servers/#{server_id}/settings"

      response = @client.delete(url, {:header => @headers})
      if response.status != 200
        cloud_error("Cannot delete settings for `#{server_id}', " \
                    "got HTTP #{response.status}")
      end

      true
    end

  end
end