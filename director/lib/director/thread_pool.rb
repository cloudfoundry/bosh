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
    end

    def process(*args, &block)
      @pool.process(*args, &block)
    end

    def raise(exception)
      @logger.debug("Worker thread raised exception: #{exception}")
      @lock.synchronize do
        @boom = exception if @boom.nil?
      end
    end

    def wait(interval = 0.1)
      sleep(interval) while @boom.nil? && @pool.working + @pool.action_size > 0
      if @boom
        @logger.debug("One of the worker threads raised an exception, shutting down pool")
        @pool.shutdown
        @logger.debug("Re-raising: #{@boom}")
        ::Kernel.raise @boom
      end
    end

  end

end