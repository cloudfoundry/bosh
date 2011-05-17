module Bosh::HealthMonitor

  class BaseAlertProcessor

    attr_reader :logger
    attr_reader :options

    def initialize(options = {})
      @logger  = Bhm.logger
      @options = options
    end

    def process(raw_alert)
      raise AlertProcessingError, "alert processing is not implemented in `#{self.class}'"
    end

  end

end
