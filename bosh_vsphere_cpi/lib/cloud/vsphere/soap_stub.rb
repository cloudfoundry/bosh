require 'httpclient'

module VSphereCloud
  class SoapStub
    def initialize(host, soap_log)
      @host = host
      @soap_log = soap_log
    end

    def create
      http_client = HTTPClient.new
      case @soap_log
        when String
          log_file = File.open(@soap_log, 'w')
          log_file.sync = true
          http_client.debug_dev = log_file
        when IO, StringIO
          http_client.debug_dev = @soap_log
      end
      http_client.send_timeout = 14400
      http_client.receive_timeout = 14400
      http_client.connect_timeout = 30
      http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

      VimSdk::Soap::StubAdapter.new(@host, 'vim.version.version8', http_client)
    end
  end
end
