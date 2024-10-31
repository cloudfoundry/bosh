require 'rspec/expectations'

module IntegrationSupport
  class Waiter
    def initialize(logger)
      @logger = logger
    end

    # Do not add retries_left default value
    def wait(retries_left, &blk)
      blk.call
    rescue StandardError, RSpec::Expectations::ExpectationNotMetError => e
      retries_left -= 1
      if retries_left > 0
        sleep(0.5)
        retry
      else
        raise e
      end
    end
  end
end
