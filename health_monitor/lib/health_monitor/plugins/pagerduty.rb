module Bosh::HealthMonitor
  module Plugins
    class Pagerduty < Base
      API_URI = "https://events.pagerduty.com/generic/2010-04-15/create_event.json"

      def run
        unless EM.reactor_running?
          logger.error("Pagerduty plugin can only be started when event loop is running")
          return false
        end

        logger.info("Pagerduty delivery agent is running...")
      end

      def validate_options
        options.kind_of?(Hash) &&
          options["service_key"].kind_of?(String)
      end

      def process(event)
        started = Time.now

        payload = {
          :service_key  => options["service_key"],
          :event_type   => "trigger",
          :incident_key => event.id,
          :description  => event.short_description,
          :details      => event.to_hash
        }

        request = {
          :body => Yajl::Encoder.encode(payload)
        }

        if options["http_proxy"]
          proxy = URI.parse(options["http_proxy"])
          request[:proxy] = { :host => proxy.host, :port => proxy.port }
        end

        send_http_request(API_URI, request)
      rescue => e
        logger.error("Error sending pagerduty event: #{e}")
      end

      def send_http_request(uri, request)
        started = Time.now
        http = EM::HttpRequest.new(uri).post(request)

        http.callback do
          logger.debug("Pagerduty event sent (took #{Time.now - started} seconds)")
        end

        http.errback do |e|
          logger.error("Failed to send pagerduty event: #{e}")
        end
      end
    end
  end
end
