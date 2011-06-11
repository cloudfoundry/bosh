module Bosh::HealthMonitor

  class EventPublisher

    SUBJECT = "bosh.hm.events"

    def initialize
      @logger     = Bhm.logger
      @event_mbus = Bhm.event_mbus
    end

    def connect_to_mbus
      unless EM.reactor_running?
        @logger.error("Event publishing requires event loop to be running")
        return false
      end

      nats_client_options = {
        :uri       => @event_mbus.endpoint,
        :user      => @event_mbus.user,
        :pass      => @event_mbus.password,
        :autostart => false
      }

      @nats = NATS.connect(nats_client_options) do
        @logger.info("Ready to publish events to NATS at `#{@event_mbus.endpoint}'")
      end
    end

    def publish_event(event)
      publish_event!(event)
    rescue Bhm::InvalidEvent => e
      @logger.error(e)
      false
    end

    def publish_event!(event)
      if @nats.nil?
        @logger.error("NATS should be initialized in order to publish events")
        return false
      end

      unless event.kind_of?(Event)
        event = Event.create!(event)
      end

      @nats.publish(SUBJECT, event.to_json)
      true
    end

  end

end
