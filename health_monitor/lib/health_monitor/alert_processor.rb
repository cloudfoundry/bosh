module Bosh::HealthMonitor

  class AlertProcessor

    def initialize
      @alert_ids = Set.new

      @agents = [ ]
      @lock   = Mutex.new
      @logger = Bhm.logger
    end

    def processed_alerts_count
      @alert_ids.size
    end

    def add_delivery_agent(agent)
      if agent.respond_to?(:validate_options) && !agent.validate_options
        raise DeliveryAgentError, "Invalid options for `#{agent.class}'"
      end

      @lock.synchronize do
        @agents << agent
      end
    end

    def register_alert(alert)
      @lock.synchronize do
        if @alert_ids.include?(alert.id)
          return true
        end
        @alert_ids << alert.id
      end

      @agents.each do |agent|
        begin
          agent.deliver(alert)
        rescue Bhm::DeliveryAgentError => e
          @logger.error("Delivery agent #{agent} failed to process alert #{alert}: #{e}")
        end
      end

      true
    end

  end

end
