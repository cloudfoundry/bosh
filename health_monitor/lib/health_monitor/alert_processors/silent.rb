module Bosh::HealthMonitor

  class SilentAlertProcessor < BaseAlertProcessor

    def process(raw_alert)
      logger.info("Silently processed alert: #{raw_alert}")
    end

  end

end
