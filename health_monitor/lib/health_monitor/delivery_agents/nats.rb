module Bosh::HealthMonitor

  class NatsDeliveryAgent < BaseDeliveryAgent

    SUBJECT = "bosh.hm.alerts"

    def initialize(options = {})
      @event_mbus = Bhm.event_mbus
      super
    end

    def run
      unless EM.reactor_running?
        logger.error("NATS delivery agent can only be started when event loop is running")
        return false
      end

      nats_client_options = {
        :uri       => @event_mbus.endpoint,
        :user      => @event_mbus.user,
        :pass      => @event_mbus.password,
        :autostart => false
      }

      @nats = NATS.connect(nats_client_options) do
        logger.info("Ready to publish alerts to NATS at `#{@event_mbus.endpoint}'")
      end
    end

    def deliver(alert)
      if @nats.nil?
        @logger.error("Cannot deliver alert, NATS not initialied")
        return false
      end

      @nats.publish(SUBJECT, alert.to_json)
      true
    end

  end

end
