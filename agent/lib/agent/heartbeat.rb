module Bosh::Agent

  class Heartbeat

    # Mostly for tests so we can override these without touching Config
    attr_accessor :logger, :nats, :agent_id, :state

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
      @state    = Config.state
    end

    def send_via_mbus
      if @state.nil?
        @logger.error("Unable to send heartbeat: agent state unknown")
        return
      end

      if @state["job"].blank?
        @logger.info("No job, skipping the heartbeat")
        return
      end

      if @nats.nil?
        raise Bosh::Agent::HeartbeatError, "NATS should be initialized in order to send heartbeats"
      end

      @nats.publish("hm.agent.heartbeat.#{@agent_id}", heartbeat_payload)
      @logger.info("Heartbeat sent")
    end

    def heartbeat_payload
      Yajl::Encoder.encode({ "job_state" => Bosh::Agent::Monit.service_group_state })
    end

  end
end
