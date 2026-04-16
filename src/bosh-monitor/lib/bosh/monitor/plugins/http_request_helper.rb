require 'async/http'
require 'async/http/internet/instance'
require 'async/http/proxy'
require 'net/http'
require 'openssl'

module Bosh::Monitor::Plugins
  module HttpRequestHelper
    include Bosh::Monitor::SSLHelpers

    def send_http_put_request(uri, request, ca_cert = nil)
      logger.debug("sending HTTP PUT to: #{uri}")
      process_async_http_request(
        method: :put,
        uri: uri,
        headers: request.fetch(:head, {}),
        body: request.fetch(:body, nil),
        proxy: request.fetch(:proxy, nil),
        ca_cert: ca_cert,
      )
    end

    def send_http_post_request(uri, request, ca_cert = nil)
      logger.debug("sending HTTP POST to: #{uri}")
      process_async_http_request(
        method: :post,
        uri: uri,
        headers: request.fetch(:head, {}),
        body: request.fetch(:body, nil),
        proxy: request.fetch(:proxy, nil),
        ca_cert: ca_cert,
      )
    end

    def send_http_get_request_synchronous(uri, ca_cert = nil, headers = nil)
      parsed_uri = URI.parse(uri.to_s)

      # we are interested in response, so send sync request
      logger.debug("Sending GET request to #{parsed_uri}")

      net_http = sync_client(parsed_uri, ca_cert)

      response = net_http.get(parsed_uri.request_uri, headers)

      [response.body, response.code.to_i]
    end

    def send_http_post_request_synchronous_with_tls_verify_peer(uri, request, ca_cert = nil)
      parsed_uri = URI.parse(uri.to_s)

      net_http = sync_client(parsed_uri, ca_cert, request.fetch(:proxy, nil))

      response = net_http.post(parsed_uri.request_uri, request[:body])

      [response.body, response.code.to_i]
    end

    private

    def resolved_proxy_uri(parsed_uri, explicit_proxy_string)
      explicit = explicit_proxy_string.to_s.strip
      return URI.parse(explicit) unless explicit.empty?

      parsed_uri.find_proxy
    end

    def sync_client(parsed_uri, ca_cert, explicit_proxy = nil)
      net_http = Net::HTTP.new(parsed_uri.host, parsed_uri.port)
      if parsed_uri.scheme == 'https'
        net_http.use_ssl = true
        configure_net_http_tls!(net_http, ca_cert)
      end

      unless (proxy_uri = resolved_proxy_uri(parsed_uri, explicit_proxy)).nil?
        net_http.proxy_address = proxy_uri.host
        net_http.proxy_port = proxy_uri.port
        net_http.proxy_user = proxy_uri.user
        net_http.proxy_pass = proxy_uri.password
      end

      net_http
    end

    def configure_net_http_tls!(net_http, ca_cert_path)
      net_http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      net_http.ca_file = ca_cert_path.to_s if configured_ca_cert?(ca_cert_path)
    end

    def process_async_http_request(method:, uri:, headers: {}, body: nil, proxy: nil, ca_cert: nil)
      name = self.class.name
      started = Time.now

      endpoint = create_async_endpoint(uri: uri, proxy: proxy, ca_cert: ca_cert)
      response = Async::HTTP::Internet.send(method, endpoint, headers, body)

      # Explicitly read the response stream to ensure the connection fully closes
      body = response.read
      status = response.status

      logger.debug("#{name} event sent (took #{Time.now - started} seconds): #{status}")
      [body, status]
    rescue => e
      logger.error("Failed to send #{name} event: #{e.class} #{e.message}\n#{e.backtrace.join('\n')}")
    ensure
      response.close if response
    end

    def create_async_endpoint(uri:, proxy:, ca_cert: nil)
      parsed_uri = URI.parse(uri.to_s)

      endpoint =
        if parsed_uri.scheme == 'https'
          ssl_context = ssl_context_for_peer_verification(ca_cert)
          Async::HTTP::Endpoint.parse(uri.to_s, ssl_context: ssl_context)
        else
          Async::HTTP::Endpoint.parse(uri.to_s)
        end

      unless (proxy_uri = resolved_proxy_uri(parsed_uri, proxy)).nil?
        client = Async::HTTP::Client.new(Async::HTTP::Endpoint.parse(proxy_uri.to_s))
        proxy = Async::HTTP::Proxy.new(client, "#{parsed_uri.host}:#{parsed_uri.port}")
        endpoint = proxy.wrap_endpoint(endpoint)
      end

      endpoint
    end
  end
end
