module Bosh::HealthMonitor

  class Agent

    attr_reader   :id
    attr_reader   :discovered_at
    attr_accessor :updated_at

    def initialize(id)
      @id            = id
      @discovered_at = Time.now
      @updated_at    = Time.now
      @logger        = Bhm.logger
      @intervals     = Bhm.intervals
    end

    def missing?
      Time.now - @updated_at > @intervals.agent_timeout
    end

    def process_heartbeat(heartbeat_payload)
      @updated_at = Time.now
    end

    def analyze
      if missing?
        @logger.warn("Agent #{@id} has timed out")
      end
    end

  end

end
