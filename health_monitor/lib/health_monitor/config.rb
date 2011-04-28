require "ostruct"

module Bosh::HealthMonitor

  class << self

    attr_accessor :logger
    attr_accessor :director
    attr_accessor :intervals
    attr_accessor :nats
    attr_accessor :mbus

    def config=(config)
      @logger       = Logging.logger(config["logfile"] || STDOUT)
      @intervals    = OpenStruct.new(config["intervals"])
      @director     = Director.new(config["director"])
      @mbus         = OpenStruct.new(config["mbus"])
    end

  end

end
