module NATS
  # create a place to keep track of a chain of certs
  def cert_chain
    @cert_chain ||= []
  end

  # EM seems to call ssl_verify_peer with each certificate in the chain, starting with the leaf
  def ssl_verify_peer(cert)
    incoming = OpenSSL::X509::Certificate.new(cert)
    cert_chain << incoming
    true   # tell EM to continue to process the handshake and present additional certs (if present)
  end

  alias_method :ssl_handshake_completed_without_chains, :ssl_handshake_completed  # rename previous implementation
  def ssl_handshake_completed
    # now we have the complete chain of SSL certificates, with the leaf in position [0]
    ca_store = OpenSSL::X509::Store.new
    ca_store.add_file(@options[:tls][:ca_file])  # make sure we check against ALL the trusted CAs provided
    unless ca_store.verify(cert_chain[0], cert_chain[1..-1])
      err_cb.call(NATS::ConnectError.new("TLS Verification failed. CA(s) did not validate against a chain of #{cert_chain.length} presented server certs"))
    end

    ssl_handshake_completed_without_chains  # call previous implementation
  end
end
