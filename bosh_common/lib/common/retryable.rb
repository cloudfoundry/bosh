require_relative 'errors'

module Bosh
  class Retryable
    def initialize(options = {})
      opts = validate_options(options)

      @ensure_callback = opts[:ensure]
      @matching        = opts[:matching]
      @on_exception    = [opts[:on]].flatten
      @try_count       = 0
      @retry_exception = nil
      @retry_limit     = opts[:tries]
      @sleeper         = opts[:sleep]
    end

    # this method will loop until the block returns a true value
    def retryer(&block)
      loop do
        @try_count += 1
        y = yield @try_count, @retry_exception
        @retry_exception = nil  # no exception was raised in the block
        return y if y
        raise Bosh::Common::RetryCountExceeded if @try_count >= @retry_limit
        wait
      end
    rescue *@on_exception => exception
      raise unless exception.message =~ @matching
      raise if @try_count >= @retry_limit

      @retry_exception = exception
      wait
      retry
    ensure
      @ensure_callback.call(@try_count)
    end

    private

    def validate_options(options)
      merged_options = default_options.merge(options)
      invalid_options = merged_options.keys - default_options.keys
      raise ArgumentError.new("Invalid options: #{invalid_options.join(", ")}") unless invalid_options.empty?

      merged_options
    end

    def default_options
      {
        tries: 2,
        sleep: exponential_sleeper,
        on: [],
        matching: /.*/,
        ensure: Proc.new {}
      }
    end

    def wait
      sleep(@sleeper.respond_to?(:call) ? @sleeper.call(@try_count, @retry_exception) : @sleeper)
    rescue *@on_exception
      # SignalException could be raised while sleeping, so if you want to catch it,
      # it need to be passed in the list of exceptions to ignore
    end

    def exponential_sleeper
      lambda { |tries, _| [2**(tries-1), 10].min } # 1, 2, 4, 8, 10, 10..10 seconds
    end

    def sleep(*args, &blk)
      Kernel.sleep(*args, &blk)
    end
  end
end

