module Bosh::Director

  # Distributed lock backed by DB.
  class Lock

    # Error returned when Lock could not be acquired.
    class TimeoutError < StandardError; end

    # Creates new lock with the given name.
    #
    # @param name lock name
    # @option opts [Number] timeout how long to wait before giving up
    # @option opts [Number] expiration how long to wait before expiring an old
    #   lock
    def initialize(name, opts = {})
      @name = name
      @uid = SecureRandom.uuid
      @timeout = opts[:timeout] || 1.0
      @expiration = opts[:expiration] || 240.0
      @logger = Config.logger
      @refresh_thread = nil
    end

    # Acquire a lock.
    #
    # @yield [void] optional block to do work before automatically releasing
    #   the lock.
    # @return [void]
    def lock
      acquire

      @refresh_thread = Thread.new do
        sleep_interval = [1.0, @expiration/2].max
        begin
          stopped = false
          until stopped
            @logger.debug("Renewing lock: #@name")
            lock_expiration = Time.now.to_f + @expiration + 1

            if Models::Lock.where(name: @name, uid: @uid).update(expired_at: Time.at(lock_expiration)) == 0
              stopped = true
            end

            sleep(sleep_interval) unless stopped
          end
        ensure
          @logger.debug("Lock renewal thread exiting")
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

    # Release a lock that was not auto released by the lock method.
    #
    # @return [void]
    def release
      @refresh_thread.exit if @refresh_thread
      delete
    end

    private

    def acquire
      @logger.debug("Acquiring lock: #@name")
      started = Time.now

      lock_expiration = Time.now.to_f + @expiration + 1
      acquired = false
      until acquired
        begin
          Models::Lock.create(name: @name, uid: @uid, expired_at: Time.at(lock_expiration))
          acquired = true
        rescue Sequel::DatabaseError
          affected_locks = Models::Lock.where(name: @name).where{ expired_at < Time.now }.update(uid: @uid, expired_at: Time.at(lock_expiration))
          if affected_locks == 1
            acquired = true
          end
        end

        unless acquired
          raise TimeoutError, "Failed to acquire lock for #{@name} uid: #{@uid}" if Time.now - started > @timeout
          sleep(0.5)
          lock_expiration = Time.now.to_f + @expiration + 1
        end
      end

      @lock_expiration = lock_expiration
      @logger.debug("Acquired lock: #@name")
    end


    def delete
      if Models::Lock.where(name: @name, uid: @uid).delete > 0
        @logger.debug("Deleted lock: #{@name} uid: #{@uid}")
      else
        @logger.debug("Can not find lock: #{@name} - uid: #{@uid}")
      end
    end

    def lock_expired?(lock_record)
      lock_record.expired_at < Time.now
    end
  end
end
