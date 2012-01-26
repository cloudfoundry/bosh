module Bosh; module Agent; end; end

require "agent_client/version"
require "agent_client/errors"
require "agent_client/base"
require "agent_client/http_client"

require "uri"
require "yajl"

module Bosh
  module Agent
    class Client
      def self.create(uri, options = { })
        scheme = URI.parse(uri).scheme
        case scheme
        when "http"
          HTTPClient.new(uri, options)
        else
          raise "Invalid client scheme, available providers are: 'http'"
        end
      end
    end
  end
end
