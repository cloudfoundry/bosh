
module Bosh::Agent
  class Infrastructure::Aws::Registry
    class << self

      def get_json_from_url(url)
        client = HTTPClient.new
        headers = { "Accept" => "application/json" }
        response = client.get(url, {}, headers)

        if response.status != 200
          raise("Cannot read settings for `#{ip}' from registry, " \
                      "got HTTP #{response.status}")
        end

        body = Yajl::Parser.parse(response.body)
        unless body.is_a?(Hash)
          raise("Invalid response from #{url} , Hash expected, " \
                      "got #{body.class}: #{body}")
        end

        body

      rescue Yajl::ParseError
        raise("Cannot parse settings for `from registry")
      end

      def get_registry_endpoint
        url = "http://169.254.169.254/latest/user-data"
        get_json_from_url(url)["registry"]["endpoint"]
      end

      def get_settings
        @registry_endpoint ||= get_registry_endpoint
        url = "#{@registry_endpoint}/settings"
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
