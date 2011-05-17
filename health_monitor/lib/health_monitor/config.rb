require "ostruct"

module Bosh::HealthMonitor

  class << self

    attr_accessor :logger
    attr_accessor :director
    attr_accessor :intervals
    attr_accessor :nats
    attr_accessor :mbus
    attr_accessor :alert_plugin
    attr_accessor :alert_options

    def config=(config)
      @logger     = Logging.logger(config["logfile"] || STDOUT)
      @intervals  = OpenStruct.new(config["intervals"])
      @director   = Director.new(config["director"])
      @mbus       = OpenStruct.new(config["mbus"])

      if config["alerts"].is_a?(Hash)
        @alert_plugin  = config["alerts"]["plugin"]
        @alert_options = config["alerts"]["options"] || { }
      end
    end

  end

end
