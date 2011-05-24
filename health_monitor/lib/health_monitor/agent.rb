module Bosh::HealthMonitor

  class Agent

    attr_reader   :id
    attr_reader   :discovered_at
    attr_accessor :updated_at

    attr_reader :job
    attr_reader :index

    def initialize(id)
      @id            = id
      @discovered_at = Time.now
      @updated_at    = Time.now
      @logger        = Bhm.logger
      @intervals     = Bhm.intervals
    end

    def timed_out?
      (Time.now - @updated_at) > @intervals.agent_timeout
    end

    def process_heartbeat(heartbeat_payload)
      @updated_at = Time.now
    end

  end

end
