# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Infrastructure::Aws::Registry
    class << self

      API_TIMEOUT           = 86400 * 3
      CONNECT_TIMEOUT       = 30
        INSTANCE_DATA_URI = "http://169.254.169.254/latest"

      def get_uri(uri)
        client = HTTPClient.new
        client.send_timeout = API_TIMEOUT
        client.receive_timeout = API_TIMEOUT
        client.connect_timeout = CONNECT_TIMEOUT

        response = client.get(INSTANCE_DATA_URI + uri)
        unless response.status == 200
          raise(LoadSettingsError, "Instance metadata endpoint returned " \
                                   "HTTP #{response.status}")
        end

        response.body
      rescue HTTPClient::BadResponseError => e
        raise(LoadSettingsError,
              "Received bad HTTP response for #{uri}: #{e.inspect}")
      rescue HTTPClient::TimeoutError
        raise(LoadSettingsError,
              "Timed out reading uri #{uri}, " \
              "please make sure agent is running on EC2 instance")
      rescue URI::Error, SocketError, Errno::ECONNREFUSED, SystemCallError => e
        raise(LoadSettingsError,
              "Error requesting current instance id from #{uri} #{e.inspect}")
      end

      ##
      # Reads current instance id from EC2 metadata. We are assuming
      # instance id cannot change while current process is running
      # and thus memoizing it.
      def current_instance_id
        return @current_instance_id if @current_instance_id
        @current_instance_id = get_uri("/meta-data/instance-id/")
      end

      def get_json_from_url(url)
        client = HTTPClient.new
        client.send_timeout = API_TIMEOUT
        client.receive_timeout = API_TIMEOUT
        client.connect_timeout = CONNECT_TIMEOUT

        headers = {"Accept" => "application/json"}
        response = client.get(url, {}, headers)

        if response.status != 200
          raise(LoadSettingsError,
                "Cannot read settings for `#{url}' from registry, " \
                "got HTTP #{response.status}")
        end

        body = Yajl::Parser.parse(response.body)
        unless body.is_a?(Hash)
          raise(LoadSettingsError,
                "Invalid response from #{url} , Hash expected, " \
                "got #{body.class}: #{body}")
        end

        body

      rescue HTTPClient::BadResponseError => e
        raise(LoadSettingsError,
              "Received bad HTTP response from registry: #{e.inspect}")
      rescue HTTPClient::TimeoutError
        raise(LoadSettingsError,
              "Timed out reading json from #{url}, " \
              "please make sure agent is running on EC2 instance")
      rescue URI::Error, SocketError, Errno::ECONNREFUSED, SystemCallError => e
        raise(LoadSettingsError,
              "Error requesting registry information #{e.inspect}")
      rescue Yajl::ParseError => e
        raise(LoadSettingsError,
              "Cannot parse settings for from registry #{e.inspect}")
      end

      def get_registry_endpoint
        user_data = get_json_from_url(INSTANCE_DATA_URI + "/user-data")
        unless user_data.has_key?("registry") &&
               user_data["registry"].has_key?("endpoint")
          raise(LoadSettingsError,
                "Cannot parse user data for endpoint #{user_data.inspect}")
        end
        Bosh::Agent::Config.logger.info("got user_data: #{user_data}")
        lookup_registry(user_data)
      end

      # If the registry endpoint is specified with a bosh dns name, e.g.
      # 0.registry.default.aws.bosh, then the agent needs to lookup the
      # name and insert the IP address, as the agent doesn't update
      # resolv.conf until after the bootstrap is run.
      def lookup_registry(user_data)
        endpoint = user_data["registry"]["endpoint"]

        # if we get data from an old director which doesn't set dns
        # info, there is noting we can do, so just return the endpoint
        if user_data["dns"].nil? || user_data["dns"]["nameserver"].nil?
          return endpoint
        end

        hostname = extract_registry_hostname(endpoint)

        # if the registry endpoint is an IP address, just return the endpoint
        unless (IPAddr.new(hostname) rescue(nil)).nil?
          return endpoint
        end

        nameservers = user_data["dns"]["nameserver"]
        ip = bosh_lookup(hostname, nameservers)
        inject_registry_ip(ip, endpoint)
      rescue Resolv::ResolvError => e
        raise(LoadSettingsError,
              "Cannot lookup #{hostname} using #{nameservers.join(', ')}" +
                  "\n#{e.inspect}")
      end

      def bosh_lookup(hostname, nameservers)
        resolver = Resolv.new([Resolv::Hosts.new, Resolv::DNS.new(nameserver: nameservers)])
        resolver.each_address(hostname) do |address|
          begin
            return address if IPAddr.new(address).ipv4?
          rescue ArgumentError
          end
        end
        raise Resolv::ResolvError, "Could not resolve #{hostname}"
      end

      def extract_registry_hostname(endpoint)
        uri = URI.parse(endpoint)
        hostname = uri.hostname

        if hostname.nil?
          raise LoadSettingsError, "Could not extract registry hostname"
        end

        hostname
      end

      def inject_registry_ip(ip, endpoint)
        uri = URI.parse(endpoint)
        uri.hostname = ip
        uri.to_s
      end

      def get_openssh_key
        get_uri("/meta-data/public-keys/0/openssh-key")
      end

      def get_settings
        @registry_endpoint ||= get_registry_endpoint
        url = "#{@registry_endpoint}/instances/#{current_instance_id}/settings"
        body = get_json_from_url(url)

        settings = Yajl::Parser.parse(body["settings"])
        unless settings.is_a?(Hash)
          raise(LoadSettingsError, "Invalid settings format, " \
                      "Hash expected, got #{settings.class}: " \
                      "#{settings}")
        end

        settings

      rescue Yajl::ParseError
        raise(LoadSettingsError,
              "Cannot parse settings from registry #{@registry_endpoint}")
      end

    end
  end
end
