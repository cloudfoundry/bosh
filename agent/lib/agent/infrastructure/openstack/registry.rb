# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Infrastructure::Openstack::Registry
    class << self

      API_TIMEOUT     = 86400 * 3
      CONNECT_TIMEOUT = 30
      SERVER_DATA_URI = "http://169.254.169.254/1.0"

      def get_uri(uri)
        client = HTTPClient.new
        client.send_timeout = API_TIMEOUT
        client.receive_timeout = API_TIMEOUT
        client.connect_timeout = CONNECT_TIMEOUT

        response = client.get(SERVER_DATA_URI + uri)
        unless response.status == 200
          raise("Server metadata endpoint returned " \
                      "HTTP #{response.status}")
        end

        response.body
      rescue HTTPClient::BadResponseError => e
        raise("Received bad HTTP response for #{uri}: #{e.inspect}")
      rescue HTTPClient::TimeoutError
        raise("Timed out reading uri #{uri}, " \
                    "please make sure agent is running on OpenStack server")
      rescue URI::Error, SocketError, Errno::ECONNREFUSED, SystemCallError => e
        raise("Error requesting current server id from #{uri} #{e.inspect}")
      end

      ##
      # Reads current server name from OpenStack user-data. We are assuming
      # server name cannot change while current process is running
      # and thus memoizing it.
      def current_server_id
        return @current_server_id if @current_server_id
        user_data = get_json_from_url(SERVER_DATA_URI + "/user-data")
        unless user_data.has_key?("server") &&
               user_data["server"].has_key?("name")
          raise("Cannot parse user data for endpoint #{user_data.inspect}")
        end
        @current_server_id = user_data["server"]["name"]
      end

      def get_json_from_url(url)
        client = HTTPClient.new
        client.send_timeout = API_TIMEOUT
        client.receive_timeout = API_TIMEOUT
        client.connect_timeout = CONNECT_TIMEOUT

        headers = {"Accept" => "application/json"}
        response = client.get(url, {}, headers)

        if response.status != 200
          raise("Cannot read settings for `#{url}' from registry, " \
                      "got HTTP #{response.status}")
        end

        body = Yajl::Parser.parse(response.body)
        unless body.is_a?(Hash)
          raise("Invalid response from #{url} , Hash expected, " \
                      "got #{body.class}: #{body}")
        end

        body

      rescue HTTPClient::BadResponseError => e
        raise("Received bad HTTP response from server registry: #{e.inspect}")
      rescue HTTPClient::TimeoutError
        raise("Timed out reading json from #{url}, " \
                    "please make sure agent is running on OpenStack server")
      rescue URI::Error, SocketError, Errno::ECONNREFUSED, SystemCallError => e
        raise("Error requesting registry information #{e.inspect}")
      rescue Yajl::ParseError => e
        raise("Cannot parse settings for from registry #{e.inspect}")
      end

      def get_registry_endpoint
        user_data = get_json_from_url(SERVER_DATA_URI + "/user-data")
        unless user_data.has_key?("registry") &&
               user_data["registry"].has_key?("endpoint")
          raise("Cannot parse user data for endpoint #{user_data.inspect}")
        end
        user_data["registry"]["endpoint"]
      end

      def get_openssh_key
        get_uri("/meta-data/public-keys/0/openssh-key")
      end

      def get_settings
        @registry_endpoint ||= get_registry_endpoint
        url = "#{@registry_endpoint}/servers/#{current_server_id}/settings"
        body = get_json_from_url(url)

        settings = Yajl::Parser.parse(body["settings"])
        unless settings.is_a?(Hash)
          raise("Invalid settings format, " \
                      "Hash expected, got #{settings.class}: " \
                      "#{settings}")
        end

        settings

      rescue Yajl::ParseError
        raise("Cannot parse settings from registry #{@registry_endpoint}")
      end

    end
  end
end
