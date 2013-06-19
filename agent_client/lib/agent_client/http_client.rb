# encoding: UTF-8

module Bosh; module Agent; end; end

module Bosh::Agent
  class HTTPClient < BaseClient

    IO_TIMEOUT      = 86400 * 3
    CONNECT_TIMEOUT = 30

    def initialize(base_uri, options = {})
      @base_uri = base_uri
      @options = options
    end

    protected

    def handle_method(method, args)
      payload = {
        'method' => method, 'arguments' => args,
        'reply_to' => @options['reply_to'] || self.class.name
      }
      post_json('/agent', Yajl::Encoder.encode(payload))
    end

    private

    def request(method, uri, content_type = nil, payload = nil, headers = {})
      headers = headers.dup
      headers['Content-Type'] = content_type if content_type

      http_client = ::HTTPClient.new

      http_client.send_timeout    = IO_TIMEOUT
      http_client.receive_timeout = IO_TIMEOUT
      http_client.connect_timeout = CONNECT_TIMEOUT
      http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http_client.ssl_config.verify_callback = proc {}

      if @options['user'] && @options['password']
        http_client.set_auth(@base_uri, @options['user'], @options['password'])
      end

      http_client.request(method, @base_uri + uri, body: payload, header: headers)

    rescue => e
      raise Error, "Request details:\n" +
          "uri: #{@base_uri + uri}\n" +
          "payload: #{payload}\n" +
          (@options['user'] ? "user: #{@options['user']}\n" : '') +
          (@options['password'] ? "password: #{@options['password']}\n" : '') +
          "#{e.class}: #{e.message}"
    end

    def post_json(url, payload)
      response = request(:post, url, 'application/json', payload)
      status = response.code
      raise AuthError, 'Authentication failed' if status == 401
      raise Error, "Agent HTTP #{status}" if status != 200
      Yajl::Parser.parse(response.body)
    end
  end
end
