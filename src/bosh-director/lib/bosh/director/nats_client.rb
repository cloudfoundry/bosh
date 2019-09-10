module Bosh::Director
  MAX_RECONNECT_ATTEMPTS = 4

  class NatsPureClientAdapter
    def connect(options)
      @nats = NATS::IO::Client.new
      @nats.on_error(&@error_handler) if @error_handler
      @nats.connect(options)
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

    def options(nats_uri, nats_client_private_key_path, nats_client_certificate_path, nats_server_ca_path)
      tls_context = OpenSSL::SSL::SSLContext.new
      tls_context.ssl_version = :TLSv1_2
      tls_context.verify_mode = OpenSSL::SSL::VERIFY_PEER

      tls_context.key = OpenSSL::PKey::RSA.new(File.open(nats_client_private_key_path))
      tls_context.cert = OpenSSL::X509::Certificate.new(File.open(nats_client_certificate_path))
      tls_context.ca_file = nats_server_ca_path

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
  end

  class NatsClientAdapter
    def connect(options)
      @nats = NATS.connect(options)
    end

    def on_error(&callback)
      NATS.on_error(&callback)
    end

    def schedule(&blk)
      EM.schedule(&blk)
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
      @nats.flush(&blk)
    end

    def options(nats_uri, nats_client_private_key_path, nats_client_certificate_path, nats_server_ca_path)
      {
        # The NATS client library has a built-in reconnection logic.
        # This logic only works when a cluster of servers is provided, by passing
        # a list of them (it will not retry a server if it receives an error from it, for
        # example a timeout). We are getting around the issue by passing the same URI
        # multiple times so the library will retry the connection. This way we are
        # adding retry logic to the director NATS connections by relying on the built-in
        # library logic.
        uris: Array.new(MAX_RECONNECT_ATTEMPTS, nats_uri),
        max_reconnect_attempts: MAX_RECONNECT_ATTEMPTS,
        reconnect_time_wait: 2,
        reconnect: true,
        ssl: true,
        tls: {
          private_key_file: nats_client_private_key_path,
          cert_chain_file: nats_client_certificate_path,
          verify_peer: true,
          ca_file: nats_server_ca_path,
        },
      }
    end
  end

  class NatsClient
    def initialize(use_nats_pure)
      @nats = if use_nats_pure
                NatsPureClientAdapter.new
              else
                NatsClientAdapter.new
              end
    end

    def connect(nats_uri, nats_client_private_key_path, nats_client_certificate_path, nats_server_ca_path)
      options = @nats.options(nats_uri, nats_client_private_key_path, nats_client_certificate_path, nats_server_ca_path)
      @nats.connect(options)
    end

    def on_error(&callback)
      @nats.on_error(&callback)
    end

    def schedule(&blk)
      @nats.schedule(&blk)
    end

    def not_connected?
      @nats.not_connected?
    end

    def subscribe(subject, &callback)
      @nats.subscribe(subject, &callback)
    end

    def publish(subject_name, request_body, &blk)
      @nats.publish(subject_name, request_body, &blk)
    end

    def flush(&blk)
      @nats.flush(&blk)
    end
  end
end
