require "httpclient"

module Bosh
  module Cli
    class ApiClient

      def initialize(base_uri, username, password)
        @base_uri  = URI.parse(base_uri)
        @client    = HTTPClient.new(:agent_name => "bosh-cli #{Bosh::Cli::VERSION}")
        @client.set_auth(nil, username, password)
      rescue URI::Error
        raise ArgumentError, "#{base_uri} is an invalid URI, cannot perform API calls"
      end

      [ :post, :put, :get, :delete ].each do |method_name|
        define_method method_name do |*args|
          request(method_name, *args)
        end
      end

      private

      def request(method, uri, content_type, payload = nil)
        response = @client.request(verb, @base_uri + uri, nil, payload, "Content-Type" => content_type)
        [ response.status, response.content ]
      end
      
    end
  end
end
