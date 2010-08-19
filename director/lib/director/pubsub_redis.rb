module Bosh::Director
  class PubsubRedis

    def initialize(redis_options)
      redis_options[:timeout] = 0
      @redis = Redis.new(redis_options)
      @mapping = {}
    end

    def subscribe(*channels, &block)
      channels.each {|channel| @mapping[channel] = block}
      if @redis.subscribed?
        @redis.subscribe(*channels)
      else
        subscribe_first(*channels)
      end
    end

    def unsubscribe(*channels)
      channels.each {|channel| @mapping.delete(channel)}
      raise "need to be subscribed before you can unsubscribe" unless @redis.subscribed?
      @redis.unsubscribe(*channels)
    end

    def subscribe_first(*channels)
      Thread.new do
        @redis.subscribe(*channels) do |on|
          on.subscribe do |channel, subscriptions|
            callback = @mapping[channel]
            callback.call(:subscribe) if callback
          end

          on.message do |channel, msg|
            callback = @mapping[channel]
            callback.call(:message, msg) if callback
          end
        end
      end
    end

  end
end