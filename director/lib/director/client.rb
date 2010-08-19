module Bosh::Director
  class Client

    class TimeoutException < StandardError; end

    attr_accessor :id

    def initialize(service_name, id, options = {})
      @service_name = service_name
      @id = id
      @redis = Config.redis
      @pubsub_redis = Config.pubsub_redis
      @timeout = options[:timeout]
    end

    def method_missing(id, *args)
      message_id = "rpc:#{UUIDTools::UUID.random_create.to_s}"
      result = {}
      result.extend(MonitorMixin)

      cond = result.new_cond
      timeout_time = Time.now.to_f + @timeout if @timeout

      @pubsub_redis.subscribe(message_id) do |*callback_args|
        type = callback_args.shift
        case type
          when :subscribe          
            payload = {
              :message_id => message_id,
              :method => id,
              :arguments => args
            }
            @redis.publish("rpc:#{@service_name}:#{@id}", Yajl::Encoder.encode(payload))
          when :message
            msg = callback_args.shift
            result.synchronize do
              result.merge!(Yajl::Parser.new.parse(msg))
              @pubsub_redis.unsubscribe(message_id)
              cond.signal
            end
          end
      end

      result.synchronize do
        while result.empty?
          timeout = nil
          if @timeout
            timeout = timeout_time - Time.now.to_f
            unless timeout > 0
              @pubsub_redis.unsubscribe(message_id)
              raise TimeoutException
            end
          end
          cond.wait(timeout)
        end
      end

      raise result["exception"] if result.has_key?("exception")
      result["value"]
    end

  end
end