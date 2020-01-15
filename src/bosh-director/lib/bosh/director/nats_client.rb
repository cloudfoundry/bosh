module Bosh::Director
  MAX_RECONNECT_ATTEMPTS = 4

  class NatsClient
    # TODO: make it initialize
    def initialize(nats_options)
      @options = nats_options
    end

    def connect
      @nats = NATS::IO::Client.new
      @nats.on_error(&@error_handler) if @error_handler
      @nats.connect(@options)
    end

    def on_error(&callback)
      @error_handler = callback
    end

    def schedule(&blk)
      blk.call
    end

    def subscribe(subject, &callback)
      @nats.subscribe(subject, &callback)
    end

    def not_connected?
      @nats.nil?
    end

    def publish(subject_name, request_body, &blk)
      @nats.publish(subject_name, request_body, &blk)
    end

    def flush(&blk)
      @nats.flush
      blk.call
    end

    def self.options(nats_uri, nats_client_private_key_path, nats_client_certificate_path, nats_server_ca_path)
      tls_context = create_tls_context(nats_client_private_key_path, nats_client_certificate_path, nats_server_ca_path)
      {
        servers: Array.new(MAX_RECONNECT_ATTEMPTS, nats_uri),
        dont_randomize_servers: true,
        max_reconnect_attempts: MAX_RECONNECT_ATTEMPTS,
        reconnect_time_wait: 0.5,
        reconnect: true,
        tls: {
          context: tls_context,
        },
      }
    end

    def self.create_tls_context(nats_client_private_key_path, nats_client_certificate_path, nats_server_ca_path)
      tls_context = OpenSSL::SSL::SSLContext.new
      tls_context.ssl_version = :TLSv1_2
      tls_context.verify_mode = OpenSSL::SSL::VERIFY_PEER

      tls_context.key = OpenSSL::PKey::RSA.new(File.open(nats_client_private_key_path))
      tls_context.cert = OpenSSL::X509::Certificate.new(File.open(nats_client_certificate_path))
      tls_context.ca_file = nats_server_ca_path
      tls_context
    end
  end
end
