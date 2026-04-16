require 'openssl'

module Bosh::Monitor
  module SSLHelpers
    def configured_ca_cert?(ca_cert_path)
      path = ca_cert_path.to_s
      return false if path.strip.empty?

      File.file?(path) && !File.zero?(path)
    rescue SystemCallError
      false
    end

    def ssl_context_for_peer_verification(ca_cert_path)
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.set_params(verify_mode: OpenSSL::SSL::VERIFY_PEER)
      ctx.ca_file = ca_cert_path.to_s if configured_ca_cert?(ca_cert_path)
      ctx
    end
  end
end
