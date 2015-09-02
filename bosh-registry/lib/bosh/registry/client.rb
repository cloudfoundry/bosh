# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.
require 'httpclient'
require 'cloud/errors'
require 'base64'

module Bosh::Registry
  ##
  # Represents Bosh Registry Client. It performs CRUD operations against
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
  class Client
    attr_reader :endpoint
    attr_reader :user
    attr_reader :password

    def initialize(endpoint, user, password)
      @endpoint = endpoint

      unless @endpoint =~ /^http:\/\//
        @endpoint = "http://#{@endpoint}"
      end

      @user = user
      @password = password

      auth = Base64.encode64("#{@user}:#{@password}").gsub("\n", '')

      @headers = {
          "Accept" => 'application/json',
          "Authorization" => "Basic #{auth}"
      }

      @client = HTTPClient.new
    end

    ##
    # Update instance settings in the registry
    # @param [String] instance_id EC2 instance id
    # @param [Hash] settings New agent settings
    # @return [Boolean]
    def update_settings(instance_id, settings)
      unless settings.is_a?(Hash)
        raise ArgumentError, "Invalid settings format, Hash expected, #{settings.class} given"
      end

      payload = Yajl::Encoder.encode(settings)
      url = "#{@endpoint}/instances/#{instance_id}/settings"

      response = @client.put(url, {:body => payload, :header => @headers})

      unless HTTP::Status.successful?(response.status)
        cloud_error("Cannot update settings for '#{instance_id}', got HTTP #{response.status}")
      end

      true
    end

    ##
    # Read instance settings from the registry
    # @param [String] instance_id EC2 instance id
    # @return [Hash] Agent settings
    def read_settings(instance_id)
      url = "#{@endpoint}/instances/#{instance_id}/settings"

      response = @client.get(url, {:header => @headers})

      if response.status != 200
        cloud_error("Cannot read settings for '#{instance_id}', got HTTP #{response.status}")
      end

      body = Yajl::Parser.parse(response.body)

      unless body.is_a?(Hash)
        cloud_error("Invalid registry response, Hash expected, got #{body.class}: #{body}")
      end

      settings = Yajl::Parser.parse(body["settings"])

      unless settings.is_a?(Hash)
        cloud_error("Invalid settings format, Hash expected, got #{settings.class}: #{settings}")
      end

      settings
    rescue Yajl::ParseError => e
      cloud_error("Cannot parse settings for '#{instance_id}': #{e.message}")
    end

    ##
    # Delete instance settings from the registry
    # @param [String] instance_id EC2 instance id
    # @return [Boolean]
    def delete_settings(instance_id)
      url = "#{@endpoint}/instances/#{instance_id}/settings"

      response = @client.delete(url, {:header => @headers})

      unless [200, 404].include? response.status
        cloud_error("Cannot delete settings for '#{instance_id}', got HTTP #{response.status}")
      end

      true
    end

    private

    def cloud_error(message)
      raise Bosh::Clouds::CloudError, message
    end
  end
end
