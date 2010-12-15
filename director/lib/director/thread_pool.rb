module ActionPool
  class Pool
    def clear
      @queue.clear
    end
  end
end

module Bosh::Director

  class ThreadPool

    def initialize(options = {})
      actionpool_options = {
        :min_threads => options[:min_threads] || 1,
        :min_threads => options[:max_threads] || 1,
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
      @logger.debug("Worker thread raised exception: #{exception}")
      @lock.synchronize do
        if @boom.nil?
          @boom = exception

          @logger.debug("Shutting down pool")
          @pool.clear
          @pool.shutdown

          @logger.debug("Re-raising: #{@boom}")
          @original_thread.raise(@boom)
        end
      end
    end

    def wait(interval = 0.1)
      sleep(interval) while @pool.working + @pool.action_size > 0
    end

  end

end