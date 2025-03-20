require 'logger'

module Bosh
  class ThreadPool
    def initialize(options = {})
      @actions = []
      @lock = Mutex.new
      @cv = ConditionVariable.new
      @max_threads = options[:max_threads] || 1
      @available_threads = @max_threads
      @logger = options[:logger]
      @boom = nil
      @original_thread = Thread.current
      @threads = []
      @state = :open
    end

    def wrap
      begin
        yield self
        wait
      ensure
        shutdown
      end
    end

    def pause
      @lock.synchronize do
        @state = :paused
      end
    end

    def resume
      @lock.synchronize do
        @state = :open
        [@available_threads, @actions.size].min.times do
          @available_threads -= 1
          create_thread
        end
      end
    end

    def process(&block)
      @lock.synchronize do
        @actions << block
        if @state == :open
          if @available_threads > 0
            @logger.debug('Creating new thread')
            @available_threads -= 1
            create_thread
          else
            @logger.debug('All threads are currently busy, queuing action')
          end
        elsif @state == :paused
          @logger.debug('Pool is paused, queueing action')
        end
      end
    end

    def create_thread
      thread = Thread.new do
        begin
          loop do
            action = nil
            @lock.synchronize do
              action = @actions.shift unless @boom
              unless action
                @logger.debug('Thread is no longer needed, cleaning up')
                @available_threads += 1
                @threads.delete(thread) if @state == :open
              end
            end

            break unless action

            begin
              action.call
            rescue Exception => e # rubocop:disable Lint/RescueException
              raise_worker_exception(e)
            end
          end
        end
        @lock.synchronize { @cv.signal unless working? }
      end
      @threads << thread
    end

    def raise_worker_exception(exception)
      if exception.respond_to?(:backtrace)
        @logger.error("Worker thread raised exception: #{exception} - #{exception.backtrace.join("\n")}")
      else
        @logger.error("Worker thread raised exception: #{exception}")
      end
      @lock.synchronize do
        @boom = exception if @boom.nil?
      end
    end

    def working?
      @boom.nil? && (@available_threads != @max_threads || !@actions.empty?)
    end

    def wait
      @logger.debug('Waiting for tasks to complete')
      @lock.synchronize do
        @cv.wait(@lock) while working?
        raise @boom if @boom
      end
    end

    def shutdown
      return if @state == :closed
      @logger.debug('Shutting down pool')
      @lock.synchronize do
        return if @state == :closed
        @state = :closed
        @actions.clear
      end
      @threads.each { |t| t.join }
    end

  end

end
