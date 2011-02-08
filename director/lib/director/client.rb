module Bosh::Director
  class Client

    class TimeoutException < StandardError; end

    attr_accessor :id

    def initialize(service_name, id, options = {})
      @service_name = service_name
      @id = id
      @nats_rpc = Config.nats_rpc
      @timeout = options[:timeout] || 30
      @logger = Config.logger
    end

    def method_missing(id, *args)
      result = {}
      result.extend(MonitorMixin)

      cond = result.new_cond
      timeout_time = Time.now.to_f + @timeout

      request = { :method => id, :arguments => args }
      request_id = @nats_rpc.send("#{@service_name}.#{@id}", request) do |response|
        result.synchronize do
          result.merge!(response)
          cond.signal
        end
      end

      result.synchronize do
        while result.empty?
          timeout = timeout_time - Time.now.to_f
          unless timeout > 0
            @nats_rpc.cancel(request_id)
            raise TimeoutException, "Timed out sending #{id} to #{@id} after #{@timeout} seconds"
          end
          cond.wait(timeout)
        end
      end

      raise result["exception"] if result.has_key?("exception")
      result["value"]
    end

    def wait_until_ready(deadline = 300)
      old_timeout = @timeout
      @timeout = 1.0
      @deadline = Time.now.to_i + deadline

      begin
        ping
      rescue TimeoutException => e
        if @deadline - Time.now.to_i > 0
          retry
        else
          raise TimeoutException, "Timed out pinging to #{@id} after #{deadline} seconds"
        end
      ensure
        @timeout = old_timeout
      end

    end

  end
end