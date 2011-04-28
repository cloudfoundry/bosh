module Bosh::HealthMonitor

  class PagerdutyDeliveryAgent < BaseDeliveryAgent

    API_URI = "https://events.pagerduty.com/generic/2010-04-15/create_event.json"

    def run
      logger.info("Pagerduty delivery agent is running...")
    end

    def validate_options
      options.kind_of?(Hash) && options["service_key"].kind_of?(String)
    end

    def deliver(alert)
      started = Time.now

      payload = {
        :service_key  => options["service_key"],
        :event_type   => "trigger",
        :incident_key => alert.id,
        :description  => format_alert_description(alert),
        :details      => format_alert_data(alert)
      }

      request = {
        :body => Yajl::Encoder.encode(payload)
      }

      if options["http_proxy"]
        proxy = URI.parse(options["http_proxy"])
        request[:proxy] = { :host => proxy.host, :port => proxy.port }
      end

      http = EM::HttpRequest.new(API_URI).post(request)

      http.callback do
        logger.debug("Pagerduty alert sent (took #{Time.now - started} seconds)")
      end

      http.errback do |e|
        logger.error("Failed to send pagerduty alert: #{e}")
      end

    rescue => e
      logger.error("Error sending pagerduty alert: #{e}")
    end

    def format_alert_description(alert)
      "Severity #{alert.severity}: #{alert.source} #{alert.title}"
    end

    def format_alert_data(alert)
      {
        :summary    => alert.summary,
        :created_at => alert.created_at.utc
      }
    end

  end

end
