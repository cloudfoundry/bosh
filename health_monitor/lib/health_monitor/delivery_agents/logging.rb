module Bosh::HealthMonitor

  class LoggingDeliveryAgent < BaseDeliveryAgent

    def deliver(alert)
      logger.info("Alert: #{format_alert(alert)}")
    end

    def format_alert(alert)
      "Alert ##{alert.id} (#{alert.created_at.utc}, severity #{alert.severity}): [#{alert.title}] #{alert.summary}"
    end

  end

end
