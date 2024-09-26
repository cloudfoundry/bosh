require 'net/http'

module Bosh::Director::ConfigServer
  class RetryableHTTPClient
    def initialize(http_client)
      @http_client = http_client
    end

    def get(path, header = nil, dest = nil, &block)
      connection_retryable.retryer do
        @http_client.get(path, header, dest, &block)
      end
    end

    def post(path, data, header = nil, dest = nil, &block)
      connection_retryable.retryer do
        @http_client.post(path, data, header, dest, &block)
      end
    end

    private

    def connection_retryable
      handled_exceptions = [
          SocketError,
          Errno::ECONNREFUSED,
          Errno::ETIMEDOUT,
          Errno::ECONNRESET,
          ::Timeout::Error,
          Net::HTTPRetriableError,
          OpenSSL::SSL::SSLError,
      ]
      Bosh::Retryable.new({sleep: 0, tries: 3, on: handled_exceptions})
    end
  end
end
