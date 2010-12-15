module Bosh::Director

  class Lock

    class TimeoutError < StandardError; end

    def initialize(name, opts = {})
      @name = name
      @id = UUIDTools::UUID.random_create.to_s
      @timeout = opts[:timeout] || 1.0
      @expiration = opts[:expiration] || 10.0
      @logger = Config.logger
    end

    def lock
      acquire

      refresh_lock_thread = Thread.new do
        redis = Config.redis
        sleep_interval = [1.0, @expiration/2].max
        begin
          loop do
            @logger.debug("Renewing lock: #{@name}")
            redis.watch(@name)
            existing_lock = redis.get(@name)
            lock_id = existing_lock.split(":")[1]
            break if lock_id != @id
            lock_expiration = Time.now.to_f + @expiration + 1
            redis.multi do
              redis.set(@name, "#{lock_expiration}:#{@id}")
            end
            sleep(sleep_interval)
          end
        ensure
          @logger.info("Lock renewal thread exiting")
          redis.quit
        end
      end

      begin
        yield
      ensure
        refresh_lock_thread.exit
        delete
      end
    end

    def acquire
      @logger.debug("Acquiring lock: #{@name}")
      redis = Config.redis
      started = Time.now

      lock_expiration = Time.now.to_f + @expiration + 1
      until redis.setnx(@name, "#{lock_expiration}:#{@id}")
        existing_lock = redis.get(@name)
        if lock_expired?(existing_lock)
          existing_lock = redis.getset(@name, "#{lock_expiration}:#{@id}")
          break if lock_expired?(existing_lock)
        end

        raise TimeoutError if Time.now - started > @timeout

        sleep(0.5)

        lock_expiration = Time.now.to_f + @expiration + 1
      end

      @lock_expiration = lock_expiration
      @logger.debug("Acquired lock: #{@name}")
    end

    def delete
      @logger.debug("Deleting lock: #{@name}")
      redis = Config.redis

      redis.watch(@name)
      existing_lock = redis.get(@name)
      lock_id = existing_lock.split(":")[1]
      if lock_id == @id
        redis.multi do
          redis.del(@name) if @lock_expiration > Time.now.to_f
        end
      else
        redis.unwatch
      end
      @logger.debug("Deleted lock: #{@name}")
    end

    def lock_expired?(lock)
      existing_lock_expiration = lock.split(":")[0].to_f
      Time.now.to_f - existing_lock_expiration > @expiration
    end

  end
end