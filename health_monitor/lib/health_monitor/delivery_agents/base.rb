module Bosh::HealthMonitor

  class BaseDeliveryAgent

    attr_reader :logger
    attr_reader :options

    def initialize(options = {})
      @logger  = Bhm.logger
      @options = options.dup
    end

    def run
      raise DeliveryAgentError, "`run' method is not implemented in `#{self.class}'"
    end

    def deliver(alert)
      raise DeliveryAgentError, "`deliver' method is not implemented in `#{self.class}'"
    end

  end

end
