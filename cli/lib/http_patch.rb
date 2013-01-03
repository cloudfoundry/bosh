class HTTPClient
  class Session
  # <Workaround patch>
  # "bosh public stemcells" don't work via http_proxy because of  https://github.com/nahi/httpclient/issues/126
  def query(req)
      connect if @state == :INIT
      req.header.request_absolute_uri = (!@proxy.nil? and !https?(@dest))
      begin
        timeout(@send_timeout, SendTimeoutError) do
          set_header(req)
          req.dump(@socket)
          # flush the IO stream as IO::sync mode is false
          @socket.flush unless @socket_sync
        end
      rescue Errno::ECONNABORTED, Errno::ECONNRESET, Errno::EPIPE, IOError
        # JRuby can raise IOError instead of ECONNRESET for now
        close
        raise KeepAliveDisconnected.new(self)
      rescue HTTPClient::TimeoutError
        close
        raise
      rescue
        close
        if SSLEnabled and $!.is_a?(OpenSSL::SSL::SSLError)
          raise KeepAliveDisconnected.new(self)
        else
          raise
        end
      end
      @state = :META if @state == :WAIT
      @next_connection = nil
      @requests.push(req)
      @last_used = Time.now
    end
  end
end
