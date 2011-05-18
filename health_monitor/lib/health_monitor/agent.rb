module Bosh::HealthMonitor

  class Agent

    OK_JOB_STATES = [ :running ]

    attr_reader   :id
    attr_reader   :discovered_at
    attr_accessor :updated_at

    def initialize(id)
      @id            = id
      @discovered_at = Time.now
      @updated_at    = Time.now
      @logger        = Bhm.logger
      @intervals     = Bhm.intervals
      @job_state     = :unknown
    end

    def missing?
      Time.now - @updated_at > @intervals.agent_timeout
    end

    def process_heartbeat(heartbeat_json)
      heartbeat   = Yajl::Parser.parse(heartbeat_json)
      @updated_at = Time.now
      @job_state  = heartbeat["job_state"].to_sym

      unless OK_JOB_STATES.include?(@job_state)
        @logger.warn("Agent #{@id} job state is #{@job_state}")
      end

    rescue Yajl::ParseError
      @logger.error("Cannot parse heartbeat json payload from #{@id}: #{heartbeat_json}")
    end

    def analyze
      if missing?
        @logger.warn("Agent #{@id} has timed out")
      end
    end

  end

end
