require 'httpclient'
require 'uri'

module Bosh::Monitor::Plugins
  module HttpRequestHelper
    def use_proxy?(uri, no_proxy)
      logger.debug("checking if uri: #{uri} is covered by no_proxy: #{no_proxy}")
      no_proxy.split(',').each do |no_proxy_host|
        # if no scheme present on uri, add http else .host will return nil
        uri = "http://#{uri}" if URI.parse(uri).scheme.nil?

        host = URI.parse(uri).host
        logger.debug("checking if uri: #{uri} is covered by no_proxy: #{no_proxy}")
        if no_proxy_host.match(/^\./) || no_proxy_host.match(/^\*\./)
          # if no_proxy_host starts with a "." or ".*" it is a wildcard.
          # We create arrays from the domain and drop the first element.
          # If the rest of the arrays has the same contents, the wildcard matches
          # eg
          # host = test.google.com => ["test","google","com"] => ["google","com"]
          # no_proxy_host_array = .google.com => ["","google","com"] => ["google","com"] => true
          # no_proxy_host_array = *.google.com => ["*","google","com"] => ["google","com"] => true
          # no_proxy_host_array = *.test.google.com => ["*","test","google","com"] => ["test","google","com"] => false
          host_array = host.downcase.split('.').drop(1)
          no_proxy_host_array = no_proxy_host.downcase.split('.').drop(1)
          return false if no_proxy_host_array.sort == host_array.sort
        end
        return false if host.downcase == no_proxy_host.downcase
      end
      true
    end
    def send_http_put_request(uri, request)
      logger.debug("sending HTTP PUT to: #{uri}")

      name = self.class.name
      started = Time.now
      http = EM::HttpRequest.new(uri).send(:put, request)
      http.callback do
        logger.debug("#{name} event sent (took #{Time.now - started} seconds): #{http.response_header.status}")
      end

      http.errback do |e|
        logger.error("Failed to send #{name} event: #{e.error}")
      end
    end

    def send_http_post_request(uri, request)
      logger.debug("sending HTTP POST to: #{uri}")

      name = self.class.name
      started = Time.now
      http = EM::HttpRequest.new(uri).send(:post, request)
      http.callback do
        logger.debug("#{name} event sent (took #{Time.now - started} seconds): #{http.response_header.status}")
      end

      http.errback do |e|
        logger.error("Failed to send #{name} event: #{e.error}")
      end
    end

    def send_http_get_request(uri)
      # we are interested in response, so send sync request
      logger.debug("Sending GET request to #{uri}")
      sync_client(OpenSSL::SSL::VERIFY_NONE).get(uri)
    end

    def send_http_post_sync_request(uri, request)
      cli = sync_client
      cli.proxy = request[:proxy] if request[:proxy]
      cli.post(uri, request[:body])
    end

    private

    def sync_client(ssl_verify_mode = OpenSSL::SSL::VERIFY_PEER)
      client = HTTPClient.new
      client.ssl_config.verify_mode = ssl_verify_mode
      client
    end
  end
end
