# encoding: UTF-8

module Bosh; module Agent; end; end

require 'httpclient'

require 'agent_client/version'
require 'agent_client/errors'
require 'agent_client/base'
require 'agent_client/http_client'

require 'uri'
require 'yajl'
require 'openssl'

module Bosh
  module Agent
    class Client
      def self.create(uri, options = { })
        scheme = URI.parse(uri).scheme
        case scheme
        when 'https'
          HTTPClient.new(uri, options)
        else
          raise "Invalid client scheme, available providers are: 'https' agent uri was: #{uri}"
        end
      end
    end
  end
end
