
module Bosh::Agent
  class Infrastructure::Aws::Registry
    class << self

      API_TIMEOUT           = 86400 * 3
      CONNECT_TIMEOUT       = 30

      ##
      # Reads current instance id from EC2 metadata. We are assuming
      # instance id cannot change while current process is running
      # and thus memoizing it.
      def current_instance_id
        return @current_instance_id if @current_instance_id

        client = HTTPClient.new
        client.send_timeout = API_TIMEOUT
        client.receive_timeout = API_TIMEOUT
        client.connect_timeout = CONNECT_TIMEOUT
        # Using 169.254.169.254 is an EC2 convention for getting
        # instance metadata
        uri = "http://169.254.169.254/1.0/meta-data/instance-id/"

        response = client.get(uri)
        unless response.status == 200
          raise("Instance metadata endpoint returned " \
                      "HTTP #{response.status}")
        end

        @current_instance_id = response.body
      rescue HTTPClient::BadResponseError => e
        raise("Received bad HTTP response for current " \
              "instance id #{uri}: #{e.inspect}")
      rescue HTTPClient::TimeoutError
        raise("Timed out reading uri #{uri}, " \
                    "please make sure agent is running on EC2 instance")
      rescue URI::Error, SocketError, Errno::ECONNREFUSED, SystemCallError => e
        raise("Error requesting current instance id from #{uri} #{e.inspect}")
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
        raise("Received bad HTTP response from instance registry: #{e.inspect}")
      rescue HTTPClient::TimeoutError
        raise("Timed out reading json from #{url}, " \
                    "please make sure agent is running on EC2 instance")
      rescue URI::Error, SocketError, Errno::ECONNREFUSED, SystemCallError => e
        raise("Error requesting registry information #{e.inspect}")
      rescue Yajl::ParseError => e
        raise("Cannot parse settings for from registry #{e.inspect}")
      end

      def get_registry_endpoint
        url = "http://169.254.169.254/latest/user-data"
        user_data = get_json_from_url(url)
        unless user_data.has_key?("registry") &&
               user_data["registry"].has_key?["endpoint"]
          raise("Cannot parse user data for endpoint #{user_data.inspect}")
        end
        user_data["registry"]["endpoint"]
      end

      def get_settings
        @registry_endpoint ||= get_registry_endpoint
        url = "#{@registry_endpoint}/instances/#{current_instance_id}/settings"
        body = get_json_from_url(url)

        settings = Yajl::Parser.parse(body["settings"])
        unless settings.is_a?(Hash)
          raise("Invalid settings format, " \
                      "Hash expected, got #{settings.class}: " \
                      "#{settings}")
        end

        settings

      rescue Yajl::ParseError
        raise("Cannot parse settings for from registry #{@registry_endpoint}")
      end

    end
  end
end
