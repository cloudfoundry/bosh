module Bosh::HealthMonitor

  class << self

    attr_accessor :logger
    attr_accessor :director
    attr_accessor :intervals
    attr_accessor :mbus
    attr_accessor :event_mbus

    attr_accessor :http_port, :http_user, :http_password
    attr_accessor :plugins
    attr_accessor :varz

    attr_accessor :nats

    def config=(config)
      validate_config(config)

      @logger     = Logging.logger(config["logfile"] || STDOUT)
      @intervals  = OpenStruct.new(config["intervals"])
      @director   = Director.new(config["director"])
      @mbus       = OpenStruct.new(config["mbus"])

      @varz = { }

      # Interval defaults
      @intervals.prune_events ||= 30
      @intervals.poll_director ||= 60
      @intervals.poll_grace_period ||= 30
      @intervals.log_stats ||= 60
      @intervals.analyze_agents ||= 60
      @intervals.agent_timeout ||= 60
      @intervals.rogue_agent_alert ||= 120

      if config["http"].is_a?(Hash)
        @http_port      = config["http"]["port"]
        @http_user      = config["http"]["user"]
        @http_password  = config["http"]["password"]
      end

      if config["event_mbus"]
        @event_mbus = OpenStruct.new(config["event_mbus"])
      end

      if config["loglevel"].is_a?(String)
        @logger.level = config["loglevel"].to_sym
      end

      if config["plugins"].is_a?(Enumerable)
        @plugins = config["plugins"]
      end
    end

    def set_varz(key, value)
      @varz ||= {}
      @varz[key] = value
    end

    def validate_config(config)
      if !config.is_a?(Hash)
        raise ConfigError, "Invalid config format, Hash epxpected, #{config.class} given"
      end
    end

  end

end
