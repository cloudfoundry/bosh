module Bosh
  module Common
    class RetryCountExceeded < StandardError; end
  end

  class Retryable
    def initialize(options = {})
      opts = validate_options(options)

      @ensure_callback = opts[:ensure]
      @matching        = opts[:matching]
      @try_count       = 0
      @retry_exception = nil
      @retry_limit     = opts[:tries]
      @sleeper         = opts[:sleep]

      @matchers = Array(opts[:on]).map do |klass_or_matcher|
        if klass_or_matcher.is_a?(Class)
          ErrorMatcher.by_class(klass_or_matcher)
        else
          klass_or_matcher
        end
      end
    end

    # Loops until the block returns a true value
    def retryer(&blk)
      loop do
        @try_count += 1
        y = blk.call(@try_count, @retry_exception)
        @retry_exception = nil # no exception was raised in the block
        return y if y
        raise Bosh::Common::RetryCountExceeded if @try_count >= @retry_limit
        wait
      end
    rescue Exception => e # rubocop:disable Lint/RescueException
      raise unless @matchers.any? { |m| m.matches?(e) }
      raise unless e.message =~ @matching
      raise if @try_count >= @retry_limit

      @retry_exception = e
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
        ensure: Proc.new {},
      }
    end

    def wait
      sleep(@sleeper.respond_to?(:call) ? @sleeper.call(@try_count, @retry_exception) : @sleeper)
    rescue Exception => e # rubocop:disable Lint/RescueException
      raise unless @matchers.any? { |m| m.matches?(e) }
      # SignalException could be raised while sleeping, so if you want to catch it,
      # it needs to be passed in the list of exceptions to ignore
    end

    def exponential_sleeper
      lambda { |tries, _| [2**(tries-1), 10].min } # 1, 2, 4, 8, 10, 10..10 seconds
    end

    def sleep(*args, &blk)
      Kernel.sleep(*args, &blk)
    end

    class ErrorMatcher
      def self.by_class(klass)
        new(klass, /.*/)
      end

      def initialize(klass, message_regex)
        @klass = klass
        @message_regex = message_regex
      end

      def matches?(error)
        !!(error.kind_of?(@klass) && error.message =~ @message_regex)
      end
    end
  end
end
