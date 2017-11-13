module Bosh::Director

  # Distributed lock backed by DB.
  class Lock

    # Error returned when Lock could not be acquired.
    class TimeoutError < StandardError;
    end

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
      @deployment_name = opts.fetch(:deployment_name, nil)
      @task_id = opts.fetch(:task_id, Config.current_job.task_id)
      @event_manager = Api::EventManager.new(Config.record_events)
      @unlock = false
      @refresh_mutex = Mutex.new
      @refresh_signal = ConditionVariable.new
    end

    # Acquire a lock.
    #
    # @yield [void] optional block to do work before automatically releasing
    #   the lock.
    # @return [void]
    def lock
      acquire

      @refresh_thread = Thread.new do
        renew_interval = [1.0, @expiration/2].max

        begin
          done_refreshing = false
          until @unlock || done_refreshing
            @refresh_mutex.synchronize do
              @refresh_signal.wait(@refresh_mutex, renew_interval)
              break if @unlock

              @logger.debug("Renewing lock: #@name")
              lock_expiration = Time.now.to_f + @expiration + 1

              if Models::Lock.where(name: @name, uid: @uid).update(expired_at: Time.at(lock_expiration)) == 0
                done_refreshing = true
              end
            end
          end
        ensure
          if !@unlock
            Models::Event.create(
              user: Config.current_job.username,
              action: 'lost',
              object_type: 'lock',
              object_name: @name,
              task: @task_id,
              deployment: @deployment_name,
              error: 'Lock renewal thread exiting',
              timestamp: Time.now,
            )

            Models::Task[@task_id].update(state: 'cancelling')

            @logger.debug('Lock renewal thread exiting')
          end
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
      @refresh_mutex.synchronize {
        @unlock = true

        delete

        @refresh_signal.signal
      }


      @refresh_thread.join if @refresh_thread
      @event_manager.create_event(
        {
          user: Config.current_job.username,
          action: 'release',
          object_type: 'lock',
          object_name: @name,
          task: @task_id,
          deployment: @deployment_name,
        }
      )
    end

    private

    def acquire
      @logger.debug("Acquiring lock: #{@name}")
      started = Time.now

      lock_expiration = Time.now.to_f + @expiration + 1
      acquired = false
      until acquired
        begin
          Models::Lock.create(name: @name, uid: @uid, expired_at: Time.at(lock_expiration), task_id: @task_id.to_s)
          acquired = true
        rescue Sequel::DatabaseError
          affected_locks = Models::Lock.where(name: @name).where { expired_at < Time.now }.update(uid: @uid, expired_at: Time.at(lock_expiration))
          if affected_locks == 1
            acquired = true
          end
        end

        unless acquired
          if Time.now - started > @timeout
            lock_message = ""
            current_lock.tap do |lock|
              lock_message = lock ? "Locking task id is #{lock.task_id}" : "Lock is gone"
            end
            raise TimeoutError, "Failed to acquire lock for #{@name} uid: #{@uid}. #{lock_message}"
          end
          sleep(0.5)
          lock_expiration = Time.now.to_f + @expiration + 1
        end
      end

      @lock_expiration = lock_expiration
      @logger.debug("Acquired lock: #{@name}")

      @event_manager.create_event(
        {
          user: Config.current_job.username,
          action: 'acquire',
          object_type: 'lock',
          object_name: @name,
          task: @task_id,
          deployment: @deployment_name,
        }
      )
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

    def current_lock
      Models::Lock.where(name: @name).first
    end
  end
end
