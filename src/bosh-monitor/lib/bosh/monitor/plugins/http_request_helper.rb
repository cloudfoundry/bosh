require 'async/http'
require 'async/http/internet/instance'
require 'async/http/proxy'
require 'net/http'

module Bosh::Monitor::Plugins
  module HttpRequestHelper
    def send_http_put_request(uri:, request:, ca_cert_path: nil)
      logger.debug("sending HTTP PUT to: #{uri}")
      process_async_http_request(
        method: :put,
        uri: uri,
        headers: request.fetch(:head, {}),
        body: request.fetch(:body, nil),
        proxy: request.fetch(:proxy, nil),
        ca_cert_path: ca_cert_path,
      )
    end

    def send_http_post_request(uri:, request:, ca_cert_path: nil)
      logger.debug("sending HTTP POST to: #{uri}")
      process_async_http_request(
        method: :post,
        uri: uri,
        headers: request.fetch(:head, {}),
        body: request.fetch(:body, nil),
        proxy: request.fetch(:proxy, nil),
        ca_cert_path: ca_cert_path,
      )
    end

    def send_http_get_request_synchronous(uri:, headers: nil, ca_cert_path: nil)
      parsed_uri = URI.parse(uri.to_s)

      # we are interested in response, so send sync request
      logger.debug("Sending GET request to #{parsed_uri}")

      net_http = sync_client(parsed_uri: parsed_uri, ca_cert_path: ca_cert_path)

      response = net_http.get(parsed_uri.request_uri, headers)

      [response.body, response.code.to_i]
    end

    def send_http_post_request_synchronous(uri:, request:, ca_cert_path: nil)
      parsed_uri = URI.parse(uri.to_s)

      net_http = sync_client(parsed_uri: parsed_uri, ca_cert_path: ca_cert_path)

      response = net_http.post(parsed_uri.request_uri, request[:body])

      [response.body, response.code.to_i]
    end

    private

    def sync_client(parsed_uri:, ca_cert_path: nil)
      net_http = Net::HTTP.new(parsed_uri.host, parsed_uri.port)
      net_http.use_ssl = (parsed_uri.scheme == 'https')
      net_http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      net_http.ca_file = ca_cert_path if usable_ca_cert?(ca_cert_path)

      env_proxy = parsed_uri.find_proxy
      unless env_proxy.nil?
        net_http.proxy_address = env_proxy.host
        net_http.proxy_port = env_proxy.port
        net_http.proxy_user = env_proxy.user
        net_http.proxy_pass = env_proxy.password
      end

      net_http
    end

    def process_async_http_request(method:, uri:, headers: {}, body: nil, proxy: nil, ca_cert_path: nil)
      name = self.class.name
      started = Time.now

      endpoint = create_async_endpoint(uri: uri, proxy: proxy, ca_cert_path: ca_cert_path)
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

    def create_async_endpoint(uri:, proxy:, ca_cert_path: nil)
      parsed_uri = URI.parse(uri.to_s)
      env_proxy = parsed_uri.find_proxy

      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_params = { verify_mode: OpenSSL::SSL::VERIFY_PEER }
      ssl_params[:ca_file] = ca_cert_path if usable_ca_cert?(ca_cert_path)
      ssl_context.set_params(ssl_params)
      endpoint = Async::HTTP::Endpoint.parse(uri).with(ssl_context: ssl_context)

      if proxy || env_proxy
        proxy_uri = proxy || "http://#{env_proxy.host}:#{env_proxy.port}"
        client = Async::HTTP::Client.new(Async::HTTP::Endpoint.parse(proxy_uri))
        proxy = Async::HTTP::Proxy.new(client, "#{parsed_uri.host}:#{parsed_uri.port}")
        endpoint = proxy.wrap_endpoint(endpoint)
      end

      endpoint
    end

    def usable_ca_cert?(ca_cert_path)
      return false if ca_cert_path.nil?

      path = ca_cert_path.to_s
      return false if path.empty?
      return false unless File.exist?(path)

      !File.read(path).strip.empty?
    end
  end
end
