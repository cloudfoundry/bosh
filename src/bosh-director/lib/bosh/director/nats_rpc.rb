module Bosh::Director
  # Remote procedure call client wrapping NATS
  class NatsRpc

    def initialize(nats_uri, nats_server_ca_path, nats_client_private_key_path, nats_client_certificate_path)
      @nats_uri = nats_uri
      @nats_server_ca_path = nats_server_ca_path
      @nats_client_private_key_path = nats_client_private_key_path
      @nats_client_certificate_path = nats_client_certificate_path

      @logger = Config.logger
      @lock = Mutex.new
      @inbox_name = "director.#{Config.process_uuid}"
      @requests = {}
      @handled_response = false
    end

    # Returns a lazily connected NATS client
    def nats
      begin
        @nats ||= connect
      rescue Exception => e
        raise "An error has occurred while connecting to NATS: #{e}"
      end
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
    def send_request(subject_name, client_id, request, options, &callback)
      request_id = generate_request_id
      request["reply_to"] = "#{@inbox_name}.#{client_id}.#{request_id}"
      @lock.synchronize do
        @requests[request_id] = [callback, options]
      end

      sanitized_log_message = sanitize_log_message(request)
      request_body = JSON.generate(request)

      @logger.debug("SENT: #{subject_name} #{sanitized_log_message}") unless options['logging'] == false

      EM.schedule do
        subscribe_inbox
        if @handled_response
          nats.publish(subject_name, request_body)
        else
          nats.flush do
            nats.publish(subject_name, request_body)
          end
        end
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
            NATS.on_error do |e|
              password = @nats_uri[/nats:\/\/.*:(.*)@/, 1]
              redacted_message = password.nil? ? "NATS client error: #{e}" : "NATS client error: #{e}".gsub(password, '*******')
              @logger.error(redacted_message)
            end
            options = {
              :uri => @nats_uri,
              :ssl => true,
              :tls => {
                :private_key_file => @nats_client_private_key_path,
                :cert_chain_file  => @nats_client_certificate_path,
                # Can enable verify_peer functionality optionally by passing
                # the location of a ca_file.
                :verify_peer => true,
                :ca_file => @nats_server_ca_path
              }
            }
            @nats = NATS.connect(options)
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
              @handled_response = true
              handle_response(message, subject)
            end
          end
        end
      end
    end

    def handle_response(message, subject)
      begin
        request_id = subject.split(".").last
        callback, options = @lock.synchronize { @requests.delete(request_id) }
        @logger.debug("RECEIVED: #{subject} #{message}") if (options && options['logging'])
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
