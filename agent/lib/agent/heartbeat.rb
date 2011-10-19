module Bosh::Agent

  class Heartbeat

    # Mostly for tests so we can override these without touching Config
    attr_accessor :logger, :nats, :agent_id, :state

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

      if @nats.nil?
        raise Bosh::Agent::HeartbeatError, "NATS should be initialized in order to send heartbeats"
      end

      @nats.publish("hm.agent.heartbeat.#{@agent_id}", heartbeat_payload) do
        yield if block_given?
        @logger.debug("Heartbeat delivered")
      end
      @logger.info("Heartbeat sent")
    end

    # Heartbeat payload example:
    # {
    #   "job": "cloud_controller",
    #   "index": 3,
    #   "job_state":"running",
    #   "vitals": {
    #     "load": ["0.09","0.04","0.01"],
    #     "cpu": {"user":"0.0","sys":"0.0","wait":"0.4"},
    #     "mem": {"percent":"3.5","kb":"145996"},
    #     "swap": {"percent":"0.0","kb":"0"},
    #     "disk": {
    #       "system": {"percent" => "82"},
    #       "ephemeral": {"percent" => "5"},
    #       "persistent": {"percent" => "94"}
    #     }
    #   }
    # }

    def heartbeat_payload
      job_state = Bosh::Agent::Monit.service_group_state
      monit_vitals = Bosh::Agent::Monit.get_vitals

      # TODO(?): move DiskUtil out of Message namespace
      disk_usage = Bosh::Agent::Message::DiskUtil.get_usage

      job_name = @state["job"] ? @state["job"]["name"] : nil
      index = @state["index"]

      vitals = monit_vitals.merge("disk" => disk_usage)

      Yajl::Encoder.encode("job" => job_name, "index" => index, "job_state" => job_state, "vitals" => vitals)
    end

  end
end
