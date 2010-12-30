module Bosh::Director
  class PubsubRedis

    def initialize(redis_options)
      redis_options[:timeout] = 0
      @redis = Redis.new(redis_options)
      @logger = Config.logger
      @lock = Mutex.new
      @mapping = {}
      setup_loop
    end

    def subscribe(*channels, &block)
      @lock.synchronize do
        channels.each {|channel| @mapping[channel] = block}
        setup_loop unless @redis.subscribed?
        @redis.subscribe(*channels)
      end
    end

    def unsubscribe(*channels)
      channels.each {|channel| @mapping.delete(channel)}
      raise "need to be subscribed before you can unsubscribe" unless @redis.subscribed?
      @redis.unsubscribe(*channels)
    end

    def setup_loop
      lock = Mutex.new
      cv = ConditionVariable.new

      Thread.new do
        begin
          @redis.subscribe("rpc:dummy") do |on|
            on.subscribe do |channel, _|
              if channel == "rpc:dummy"
                lock.synchronize { cv.signal }
              else
                callback = @mapping[channel]
                callback.call(:subscribe) if callback
              end
            end

            on.message do |channel, msg|
              callback = @mapping[channel]
              callback.call(:message, msg) if callback
            end
          end
        rescue Exception => e
          @logger.warn("PubSub error => #{e} - #{e.backtrace.join("\n")}")
          raise e
        end
      end

      lock.synchronize { cv.wait(lock) }
    end

  end
end
