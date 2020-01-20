module Bosh::Director
  MAX_RECONNECT_ATTEMPTS = 4

  class NatsClient
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
