# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AWSCloud
  class RegistryClient
    include Helpers

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

      auth = Base64.encode64("#{@user}:#{@password}").gsub("\n", "")

      @headers = {
        "Accept" => "application/json",
        "Authorization" => "Basic #{auth}"
      }

      @client = HTTPClient.new
    end

    ##
    # Read settings for given IP from the registry
    # @param [String] ip Agent IP address
    # @param [Hash] settings New agent settings
    # @return [Boolean]
    def update_settings(ip, settings)
      unless settings.is_a?(Hash)
        raise ArgumentError, "Invalid settings format, " \
                             "Hash expected, #{settings.class} given"
      end

      payload = Yajl::Encoder.encode(settings)
      url = "#{@endpoint}/agents/#{ip}/settings"

      response = @client.put(url, payload, @headers)

      if response.status != 200
        cloud_error("Cannot update settings for `#{ip}' in registry, " \
                    "got HTTP #{response.status}")
      end

      true
    end

    ##
    # Read settings for given IP from the registry
    # @param [String] ip Agent IP address
    # @return [Hash] Agent settings
    def read_settings(ip)
      url = "#{@endpoint}/agents/#{ip}/settings"

      response = @client.get(url, {}, @headers)

      if response.status != 200
        cloud_error("Cannot read settings for `#{ip}' from registry, " \
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
      cloud_error("Cannot parse settings for `#{ip} from registry")
    end

    ##
    # Read settings for given IP from the registry
    # @param [String] ip Agent IP address
    # @return [Boolean]
    def delete_settings(ip)
      url = "#{@endpoint}/agents/#{ip}/settings"

      response = @client.delete(url, @headers)

      if response.status != 200
        cloud_error("Cannot delete settings for `#{ip}' in registry, " \
                    "got HTTP #{response.status}")
      end

      true
    end

  end

end
