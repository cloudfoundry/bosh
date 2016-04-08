module Bosh::Director
  class ErrorIgnorer
    def initialize(force, logger)
      @force = force
      @logger = logger
    end

    def with_force_check
      yield
    rescue => e
      raise unless @force
      @logger.warn(e.backtrace.join("\n"))
      @logger.info('Force deleting is set, ignoring exception')
    end
  end
end
