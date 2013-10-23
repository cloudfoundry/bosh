module Bosh::Monitor
  class DirectorMonitor
    def initialize(config)
      @nats = config.nats
      @logger = config.logger
      @event_processor = config.event_processor
    end

    def subscribe
      @nats.subscribe('hm.director.alert') do |msg|
        alert = Yajl::Parser.parse(msg)

        if valid_payload?(alert)
          @event_processor.process(:alert, alert)
        end
      end
    end

    private

    def valid_payload?(payload)
      missing_keys = %w(id severity title summary created_at) - payload.keys
      valid = missing_keys.empty?

      unless valid
        first_missing_key = missing_keys.first
        @logger.error("Invalid payload from director: the key '#{first_missing_key}' was missing. #{payload.inspect}")
      end

      valid
    end
  end
end
