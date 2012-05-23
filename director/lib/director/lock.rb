# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director

  class Lock

    class TimeoutError < StandardError; end
    class LockBusy < StandardError; end

    def initialize(name, opts = {})
      @name = name
      @id = UUIDTools::UUID.random_create.to_s
      @timeout = opts[:timeout] || 1.0
      @expiration = opts[:expiration] || 10.0
      @logger = Config.logger
      @refresh_thread = nil
    end

    def lock(&block)
      lock_int(&block)
    end

    def try_lock(&block)
      lock_int(true, &block)
    end

    def acquire(non_blocking)
      @logger.debug("Acquiring lock: #{@name}")
      redis = Config.redis
      started = Time.now

      lock_expiration = Time.now.to_f + @expiration + 1
      until redis.setnx(@name, "#{lock_expiration}:#{@id}")
        existing_lock = redis.get(@name)
        @logger.debug("Lock #{@name} is already locked by someone else: #{existing_lock}")
        if lock_expired?(existing_lock)
          @logger.debug("Lock #{@name} is already expired, trying to take it back")
          replaced_lock = redis.getset(@name, "#{lock_expiration}:#{@id}")
          if replaced_lock == existing_lock
            @logger.debug("Lock #{@name} was revoked and relocked")
            break
          else
            @logger.debug("Lock #{@name} was acquired by someone else, trying again")
          end
        end

        raise LockBusy if non_blocking

        raise TimeoutError if Time.now - started > @timeout

        sleep(0.5)

        lock_expiration = Time.now.to_f + @expiration + 1
      end

      @lock_expiration = lock_expiration
      @logger.debug("Acquired lock: #{@name}")
    end

    def release
      @refresh_thread.exit if @refresh_thread
      delete
    end

    def delete
      @logger.debug("Deleting lock: #{@name}")
      redis = Config.redis

      redis.watch(@name)
      existing_lock = redis.get(@name)
      lock_id = existing_lock.split(":")[1]
      if lock_id == @id
        redis.multi do
          redis.del(@name)
        end
      else
        redis.unwatch
      end
      @logger.debug("Deleted lock: #{@name}")
    end

    def lock_expired?(lock)
      existing_lock_expiration = lock.split(":")[0].to_f
      lock_time_left = existing_lock_expiration - Time.now.to_f
      @logger.info("Lock: #{lock} expires in #{lock_time_left} seconds")
      lock_time_left < 0
    end

    private
    def lock_int(non_blocking = false)
      acquire(non_blocking)

      @refresh_thread = Thread.new do
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
          @logger.debug("Lock renewal thread exiting")
          redis.quit
        end
      end

      if block_given?
        begin
          yield
        ensure
          release
        end
      end
    end

  end
end
