module Bosh::Director
  # Remote procedure call client wrapping NATS
  class NatsRpc

    def initialize(nats_uri)
      @nats_uri = nats_uri
      @logger = Config.logger
      @lock = Mutex.new
      @inbox_name = "director.#{Config.process_uuid}"
      @requests = {}
    end

    # Returns a lazily connected NATS client
    def nats
      @nats ||= connect
    end

    # Publishes a payload (encoded as JSON) without expecting a response
    def send_message(client, payload)
      message = JSON.generate(payload)
      @logger.debug("SENT: #{client} #{message}")
      EM.schedule do
        nats.publish(client, message)
      end
    end

    # Sends a request (encoded as JSON) and listens for the response
    def send_request(client, request, &callback)
      request_id = generate_request_id
      request["reply_to"] = "#{@inbox_name}.#{request_id}"
      @lock.synchronize do
        @requests[request_id] = callback
      end

      sanitized_log_message = sanitize_log_message(request)
      request_body = JSON.generate(request)

      @logger.debug("SENT: #{client} #{sanitized_log_message}")
      EM.schedule do
        subscribe_inbox
        nats.publish(client, request_body)
      end
      request_id
    end

    # Stops listening for a response
    def cancel_request(request_id)
      @lock.synchronize { @requests.delete(request_id) }
    end

    def generate_request_id
      SecureRandom.uuid
    end

    private

    def connect
      # double-check locking to reduce synchronization
      if @nats.nil?
        @lock.synchronize do
          if @nats.nil?
            @nats = NATS.connect(:uri => @nats_uri, :autostart => false)
          end
        end
      end
      @nats
    end

    # subscribe to an inbox, if not already subscribed
    def subscribe_inbox
      # double-check locking to reduce synchronization
      if @subject_id.nil?
        # nats lazy-load needs to be outside the synchronized block
        client = nats
        @lock.synchronize do
          if @subject_id.nil?
            @subject_id = client.subscribe("#{@inbox_name}.>") do |message, _, subject|
              handle_response(message, subject)
            end
          end
        end
      end
    end

    def handle_response(message, subject)
      @logger.debug("RECEIVED: #{subject} #{message}")
      begin
        request_id = subject.split(".").last
        callback = @lock.synchronize { @requests.delete(request_id) }
        if callback
          message = message.empty? ? nil : JSON.parse(message)
          callback.call(message)
        end
      rescue Exception => e
        @logger.warn(e.message)
      end
    end

    def sanitize_log_message(request)
      if request[:method].to_s == 'upload_blob'
        cloned_request = Bosh::Common::DeepCopy.copy(request)
        cloned_request[:arguments].first['checksum'] = '<redacted>'
        cloned_request[:arguments].first['payload'] = '<redacted>'
        JSON.generate(cloned_request)
      else
        JSON.generate(request)
      end
    end

  end
end
