module Bosh::HealthMonitor

  class Agent

    attr_reader   :id
    attr_reader   :discovered_at
    attr_accessor :updated_at

    attr_writer :job
    attr_writer :index
    attr_writer :deployment

    def initialize(id, deployment = nil, job = nil, index = nil)
      @id            = id
      @discovered_at = Time.now
      @updated_at    = Time.now
      @logger        = Bhm.logger
      @intervals     = Bhm.intervals
      @deployment    = deployment
      @job           = job
      @index         = index
    end

    def name
      "#{deployment}: #{job}(#{index}) [#{@id}]"
    end

    def job
      @job || "unknown job"
    end

    def index
      @index || "index n/a"
    end

    def deployment
      @deployment || "unknown deployment"
    end

    def timed_out?
      (Time.now - @updated_at) > @intervals.agent_timeout
    end

    def rogue?
      (Time.now - @discovered_at) > @intervals.rogue_agent_alert && @deployment.nil?
    end

    def process_heartbeat(heartbeat_payload)
      @updated_at = Time.now
    end

  end

end
