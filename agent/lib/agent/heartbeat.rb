module Bosh::Agent

  class Heartbeat

    # Mostly for tests so we can override these without touching Config
    attr_accessor :logger, :nats, :agent_id, :state

    def self.enable(interval)
      unless EM.reactor_running?
        raise Bosh::Agent::HeartbeatError, "Event loop must be running in order to enable heartbeats"
      end

      EM.add_periodic_timer(interval) do
        begin
          new.send_via_mbus
        rescue => e
          Config.logger.warn("Error sending heartbeat: #{e}")
          Config.logger.warn(e.backtrace.join("\n"))
        end
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


    # Heartbeat payload example:
    # {
    #   "job_state":"running",
    #   "vitals":{
    #     "cloud_controller":{
    #       "status":"running",
    #       "children":"0",
    #       "uptime":"213",
    #       "memory":{"percent":"1.6","kb":"67436"},
    #       "memory_total":{"percent":"1.6","kb":"67436"},
    #       "cpu":"0.0",
    #       "cpu_total":"0.0"
    #     },
    #     "nginx":{
    #       "status":"running",      "children":"1",
    #       "uptime":"211",
    #       "memory":{"percent":"0.0","kb":"952"},
    #       "memory_total":{"percent":"0.1","kb":"5428"},
    #       "cpu":"0.0",
    #       "cpu_total":"0.0"
    #      }
    #    }
    #  }
    #}
    def heartbeat_payload
      status = Bosh::Agent::Monit.get_status

      job_state = Bosh::Agent::Monit.service_group_state(status)
      vitals = Bosh::Agent::Monit.get_vitals(status)

      Yajl::Encoder.encode("job_state" => job_state, "vitals" => vitals)
    end

  end
end
