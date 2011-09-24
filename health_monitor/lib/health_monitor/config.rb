require "ostruct"

module Bosh::HealthMonitor

  class << self

    attr_accessor :logger
    attr_accessor :director
    attr_accessor :intervals
    attr_accessor :nats
    attr_accessor :mbus
    attr_accessor :event_mbus

    attr_accessor :http_port, :http_user, :http_password
    attr_accessor :alert_delivery_agents
    attr_accessor :varz

    def config=(config)
      @logger     = Logging.logger(config["logfile"] || STDOUT)
      @intervals  = OpenStruct.new(config["intervals"])
      @director   = Director.new(config["director"])
      @mbus       = OpenStruct.new(config["mbus"])

      @varz = { }

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

      if config["alert_delivery_agents"].kind_of?(Array)
        @alert_delivery_agents = config["alert_delivery_agents"]
      else
        @alert_delivery_agents = [ ]
        @logger.warn("Unknown format for alert_delivery_agents in config file, Array expected")
      end
    end

    def set_varz(key, value)
      @varz[key] = value
    end

  end

end
