module Bosh::Agent

  class HeartbeatError < StandardError; end

  class Heartbeat

    attr_accessor :logger, :nats, :agent_id # Mostly for tests

    def self.enable(interval)
      unless EM.reactor_running?
        raise Bosh::Agent::HeartbeatError, "Event loop must be running in order to enable heartbeats"
      end

      EM.add_periodic_timer(interval) do
        new.send_via_mbus
      end
    end

    def initialize
      @logger   = Config.logger
      @nats     = Config.nats
      @agent_id = Config.agent_id
    end

    def send_via_mbus
      if @nats.nil?
        raise Bosh::Agent::HeartbeatError, "NATS should be initialized in order to send heartbeats"
      end

      @nats.publish("hm.agent.heartbeat.#{@agent_id}", heartbeat_payload)
      @logger.info("Heartbeat sent")
    end

    def heartbeat_payload
      # FIXME: Using agent state message handler here is probably fine
      # for the initial implementation but we need to keep an eye on it,
      # maybe abstract it to a separate class and make both this code
      # and state message handler clients of this class.

      # TODO: send only what really needed
      state_handler = Bosh::Agent::Message::State.new(nil)
      state_handler.state
    end

  end
end
