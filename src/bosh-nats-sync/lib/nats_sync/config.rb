require 'logging'

module NATSSync
  class << self
    attr_reader :logger

    def config=(config)
      @logger = Logging.logger(config['logfile'] || STDOUT)
      @logger.level = :info
    end
  end
end
