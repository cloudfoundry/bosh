require 'async/http'
require 'async/http/proxy'
require 'net/http'

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
      parsed_uri = URI.parse(uri.to_s)

      # we are interested in response, so send sync request
      logger.debug("Sending GET request to #{parsed_uri}")

      net_http = sync_client(parsed_uri, OpenSSL::SSL::VERIFY_NONE)

      response = net_http.get(parsed_uri.request_uri, headers)

      [response.body, response.code.to_i]
    end

    def send_http_post_sync_request(uri, request)
      parsed_uri = URI.parse(uri.to_s)

      net_http = sync_client(parsed_uri, OpenSSL::SSL::VERIFY_PEER)

      response = net_http.post(parsed_uri.request_uri, request[:body])

      [response.body, response.code.to_i]
    end

    private

    def sync_client(parsed_uri, ssl_verify_mode)
      net_http = Net::HTTP.new(parsed_uri.host, parsed_uri.port)
      net_http.use_ssl = (parsed_uri.scheme == 'https')
      net_http.verify_mode = ssl_verify_mode

      env_proxy = parsed_uri.find_proxy
      unless env_proxy.nil?
        net_http.proxy_address = env_proxy.host
        net_http.proxy_port = env_proxy.port
        net_http.proxy_user = env_proxy.user
        net_http.proxy_pass = env_proxy.password
      end

      net_http
    end

    def process_async_http_request(method:, uri:, headers: {}, body: nil, proxy: nil)
      name = self.class.name
      started = Time.now

      client = create_async_client(uri: uri, proxy: proxy)
      parsed_uri = URI.parse(uri.to_s)
      response = client.send(method, parsed_uri.path, headers, body)

      # Explicitly read the response stream to ensure the connection fully closes
      body = response.read
      status = response.status

      logger.debug("#{name} event sent (took #{Time.now - started} seconds): #{status}")
      [body, status]
    rescue => e
      logger.error("Failed to send #{name} event: #{e.class} #{e.message}\n#{e.backtrace.join('\n')}")
    ensure
      client.close if client
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
