module Bosh; module Agent; end; end

require "httpclient"

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
        "method" => method, "arguments" => args,
        "reply_to" => @options["reply_to"] || self.class.name
      }
      result = post_json("/agent", Yajl::Encoder.encode(payload))
    end

    private

    def request(method, uri, content_type = nil, payload = nil, headers = {})
      headers = headers.dup
      headers["Content-Type"] = content_type if content_type

      http_client = ::HTTPClient.new

      http_client.send_timeout    = IO_TIMEOUT
      http_client.receive_timeout = IO_TIMEOUT
      http_client.connect_timeout = CONNECT_TIMEOUT

      if @options['user'] && @options['password']
        http_client.set_auth(@base_uri, @options['user'], @options['password'])
      end

      http_client.request(method, @base_uri + uri,
                          :body => payload, :header => headers)

    rescue URI::Error, SocketError, Errno::ECONNREFUSED => e
      raise Error, "cannot access agent (%s)" % [ e.message ]
    rescue SystemCallError => e
      raise Error, "System call error while talking to agent: #{e}"
    rescue ::HTTPClient::BadResponseError => e
      raise Error, "Received bad HTTP response from agent: #{e}"
    rescue => e
      raise Error, "Agent call exception: #{e}"
    end

    def post_json(url, payload)
      response = request(:post, url, "application/json", payload)
      status = response.code
      raise AuthError, "Authentication failed" if status == 401
      raise Error, "Agent HTTP #{status}" if status != 200
      Yajl::Parser.parse(response.body)
    end

  end
end
