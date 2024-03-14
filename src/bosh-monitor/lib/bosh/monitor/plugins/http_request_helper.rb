require 'httpclient'
require 'async/http'
require 'async/http/proxy'

module Bosh::Monitor::Plugins
  module HttpRequestHelper
    def send_http_put_request(uri, request)
      logger.debug("sending HTTP PUT to: #{uri}")
      process_async_http_request(method: :put, uri: uri, headers: request.fetch(:head, {}), body: request.fetch(:body, nil), proxy: request.fetch(:proxy, nil))
    end

    def send_http_post_request(uri, request)
      logger.debug("sending HTTP POST to: #{uri}")
      process_async_http_request(method: :post, uri: uri, headers: request.fetch(:head, {}), body: request.fetch(:body, nil), proxy: request.fetch(:proxy, nil))
    end

    def send_http_get_request(uri, headers = nil)
      # we are interested in response, so send sync request
      logger.debug("Sending GET request to #{uri}")
      cli = sync_client(OpenSSL::SSL::VERIFY_NONE)
      env_proxy = URI.parse(uri.to_s).find_proxy
      cli.proxy = env_proxy unless env_proxy.nil?

      return cli.get(uri) if headers.nil?

      cli.get(uri, nil, headers)
    end

    def send_http_post_sync_request(uri, request)
      cli = sync_client
      env_proxy = URI.parse(uri.to_s).find_proxy
      cli.proxy = env_proxy unless env_proxy.nil?
      cli.post(uri, request[:body])
    end

    private

    def sync_client(ssl_verify_mode = OpenSSL::SSL::VERIFY_PEER)
      client = HTTPClient.new
      client.ssl_config.verify_mode = ssl_verify_mode
      client
    end

    def process_async_http_request(method:, uri:, headers: {}, body: nil, proxy: nil)
      name = self.class.name
      started = Time.now

      client = create_async_client(uri: uri, proxy: proxy)
      parsed_uri = URI.parse(uri.to_s)
      response = client.send(method, parsed_uri.path, headers, body)

      logger.debug("#{name} event sent (took #{Time.now - started} seconds): #{response.status}")
      response
    rescue => e
      logger.error("Failed to send #{name} event: #{e.class} #{e.message}\n#{e.backtrace.join('\n')}")
    end

    def create_async_client(uri:, proxy:)
      parsed_uri = URI.parse(uri.to_s)
      env_proxy = parsed_uri.find_proxy

      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.set_params(verify_mode: OpenSSL::SSL::VERIFY_NONE)
      endpoint = Async::HTTP::Endpoint.parse(uri).with(ssl_context: ssl_context)

      if proxy || env_proxy
        proxy_uri = proxy || "http://#{env_proxy.host}:#{env_proxy.port}"
        client = Async::HTTP::Client.new(Async::HTTP::Endpoint.parse(proxy_uri))
        proxy = Async::HTTP::Proxy.new(client, "#{parsed_uri.host}:#{parsed_uri.port}")
        endpoint = proxy.wrap_endpoint(endpoint)
      end

      Async::HTTP::Client.new(endpoint)
    end
  end
end
