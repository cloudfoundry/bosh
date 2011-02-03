module Bosh::Director

  class ThreadPool

    def initialize(options = {})
      actionpool_options = {
        :min_threads => options[:min_threads] || 1,
        :max_threads => options[:max_threads] || 1,
        :respond_thread => self
      }
      @pool = ActionPool::Pool.new(actionpool_options)
      @logger = Config.logger
      @boom = nil
      @lock = Mutex.new
      @original_thread = Thread.current
    end

    def process(*args, &block)
      @pool.process(*args, &block)
    end

    def raise(exception)
      if exception.respond_to?(:backtrace)
        @logger.debug("Worker thread raised exception: #{exception} - #{exception.backtrace.join("\n")}")
      else
        @logger.debug("Worker thread raised exception: #{exception}")
      end
      @lock.synchronize do
        if @boom.nil?
          Thread.new do
            @boom = exception

            @logger.debug("Shutting down pool")
            @pool.shutdown

            @logger.debug("Re-raising: #{@boom}")
            @original_thread.raise(@boom)
          end
        end
      end
    end

    def working?
      !@boom.nil? || @pool.working + @pool.action_size > 0
    end

    def wait(interval = 0.1)
      @logger.debug("Waiting for tasks to complete")
      sleep(interval) while working?
    end

    def shutdown
      @logger.debug("Shutting down pool")
      @pool.shutdown
    end

  end

end