module Bosh::Monitor
  class << self
    attr_accessor :logger
    attr_accessor :director
    attr_accessor :intervals
    attr_accessor :mbus
    attr_accessor :event_mbus
    attr_accessor :instance_manager
    attr_reader :resurrection_manager
    attr_accessor :event_processor

    attr_accessor :http_port
    attr_accessor :plugins

    attr_accessor :nats

    def config=(config)
      validate_config(config)

      @logger = Logging.logger(config['logfile'] || STDOUT)
      @intervals = OpenStruct.new(config['intervals'])
      @director = Director.new(config['director'], @logger)
      @mbus = OpenStruct.new(config['mbus'])

      @event_processor = EventProcessor.new
      @instance_manager = InstanceManager.new(event_processor)
      @resurrection_manager = ResurrectionManager.new

      # Interval defaults
      @intervals.prune_events ||= 30
      @intervals.poll_director ||= 60
      @intervals.poll_grace_period ||= 30
      @intervals.log_stats ||= 60
      @intervals.analyze_agents ||= 60
      @intervals.analyze_instances ||= 60
      @intervals.agent_timeout ||= 60
      @intervals.rogue_agent_alert ||= 120
      @intervals.resurrection_config ||= 60

      @http_port = config['http']['port'] if config['http'].is_a?(Hash)

      @event_mbus = OpenStruct.new(config['event_mbus']) if config['event_mbus']

      @logger.level = config['loglevel'].to_sym if config['loglevel'].is_a?(String)

      @plugins = config['plugins'] if config['plugins'].is_a?(Enumerable)
    end

    def validate_config(config)
      raise ConfigError, "Invalid config format, Hash expected, #{config.class} given" unless config.is_a?(Hash)
    end
  end
end
