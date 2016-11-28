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
      @logger.error("Force deleting is set, ignoring exception: #{e.inspect}\n#{e.backtrace.join("\n")}")
    end
  end
end
