module Bosh::HealthMonitor::Plugins
  module HttpRequestHelper
    def send_http_request(name, uri, request)
      started = Time.now
      http = EM::HttpRequest.new(uri).post(request)

      http.callback do
        logger.debug("#{name} event sent (took #{Time.now - started} seconds)")
      end

      http.errback do |e|
        logger.error("Failed to send #{name} event: #{e}")
      end
    end
  end
end
