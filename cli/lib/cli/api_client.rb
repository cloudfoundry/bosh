require "httpclient"

module Bosh
  module Cli
    class ApiClient

      class InvalidMethod < StandardError; end

      def initialize(target_uri, username, password)
        @target_uri   = URI.parse(target_uri)
        @http_client  = HTTPClient.new(:agent_name => "bosh-cli")
        @http_client.set_auth(@target_uri, username, password)
      end

      def request(verb, uri, payload = nil, content_type = "application/octet-stream")
        raise InvalidMethod unless [ :post, :put, :get, :delete ].include?(verb.to_sym)
        response = @http_client.request(verb, @target_uri + uri, nil, payload, "Content-Type" => content_type)
        [ response.status, response.content ]
      end
      
    end
  end
end
