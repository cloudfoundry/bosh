module Bosh::Director
  # Remote procedure call client wrapping NATS
  class NatsRpc

    MAX_RECONNECT_ATTEMPTS = 4

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

    def nats
      init_nats if @nats.nil?
      begin
        unless @nats.connected?
          @lock.synchronize do
            @nats.connect(@nats_options) unless @nats.connected?
          end
        end
      rescue Errno::ECONNREFUSED
        @logger.error("NATS connection refused")
      rescue Exception => e
        raise "An error has occurred while connecting to NATS: #{e}"
      end
      @nats
    end

    # Publishes a payload (encoded as JSON) without expecting a response
    def send_message(client, payload)
      message = JSON.generate(payload)
      @logger.debug("SENT: #{client} #{message}")

      if nats.connected?
        @nats.publish(client, message)
      else
        @logger.error("SENT failed because nats isn't connected: #{client} #{message}")
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

      if nats.connected?
        subscribe_inbox
        @nats.publish(subject_name, request_body)
      else
        @logger.error("SENT failed because nats isn't connected: #{subject_name} #{sanitized_log_message}")
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

    def init_nats
      @lock.synchronize do
        if @nats.nil?
          @nats = NATS::IO::Client.new

          tls_context = OpenSSL::SSL::SSLContext.new
          tls_context.ssl_version = :TLSv1_2
          tls_context.verify_mode = OpenSSL::SSL::VERIFY_PEER

          tls_context.key = OpenSSL::PKey::RSA.new(File.open(@nats_client_private_key_path))
          tls_context.cert = OpenSSL::X509::Certificate.new(File.open(@nats_client_certificate_path))
          tls_context.ca_file = @nats_server_ca_path

          @nats_options = {
            servers: Array.new(MAX_RECONNECT_ATTEMPTS, @nats_uri),
            dont_randomize_servers: true,
            max_reconnect_attempts: MAX_RECONNECT_ATTEMPTS,
            reconnect_time_wait: 2,
            reconnect: true,
            tls: {
              context: tls_context,
            },
          }

          @nats.on_error do |e|
            password = @nats_uri[%r{nats://.*:(.*)@}, 1]
            redacted_message = password.nil? ? "NATS client error: #{e}" : "NATS client error: #{e}".gsub(password, '*******')
            @logger.error(redacted_message)
          end
        end
      end
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
        end if client.connected?
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
        cloned_request = Bosh::Director::DeepCopy.copy(request)
        cloned_request[:arguments].first['checksum'] = '<redacted>'
        cloned_request[:arguments].first['payload'] = '<redacted>'
        JSON.generate(cloned_request)
      elsif request[:method].to_s == 'update_settings'
        cloned_request = Bosh::Director::DeepCopy.copy(request)
        cloned_request[:arguments].first['mbus'] = '<redacted>'
        cloned_request[:arguments].first['blobstores'] = '<redacted>'
        JSON.generate(cloned_request)
      else
        JSON.generate(request)
      end
    end
  end
end
