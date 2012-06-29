# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class NatsRpc

    def initialize
      @nats = Config.nats
      @logger = Config.logger
      @lock = Mutex.new
      @inbox_name = "director.#{Config.process_uuid}"
      @requests = {}
      subscribe_inbox
    end

    def subscribe_inbox
      @nats.subscribe("#{@inbox_name}.>") do |message, _, subject|
        @logger.debug("RECEIVED: #{subject} #{message}")
        begin
          request_id = subject.split(".").last
          callback = @lock.synchronize { @requests.delete(request_id) }
          if callback
            message = Yajl::Parser.new.parse(message)
            callback.call(message)
          end
        rescue Exception => e
          @logger.warn(e.message)
        end
      end
    end

    def send_request(client, request, &block)
      request_id = generate_request_id
      request["reply_to"] = "#{@inbox_name}.#{request_id}"
      @lock.synchronize do
        @requests[request_id] = block
      end
      message = Yajl::Encoder.encode(request)
      @logger.debug("SENT: #{client} #{message}")
      EM.next_tick do
        @nats.publish(client, message)
      end
      request_id
    end

    def cancel_request(request_id)
      @lock.synchronize { @requests.delete(request_id) }
    end

    def generate_request_id
      UUIDTools::UUID.random_create.to_s
    end

  end
end
