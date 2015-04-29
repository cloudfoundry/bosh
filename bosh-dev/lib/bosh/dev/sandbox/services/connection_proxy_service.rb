module Bosh::Dev::Sandbox
  class ConnectionProxyService
    REPO_ROOT = File.expand_path('../../../../../../', File.dirname(__FILE__))
    ASSETS_DIR = File.expand_path('bosh-dev/assets/sandbox', REPO_ROOT)
    TCP_PROXY = File.join(ASSETS_DIR, 'proxy/tcp-proxy')

    def initialize(forward_to_host, forward_to_port, listen_port, logger)
      @logger = logger
      @process = Service.new(%W[#{TCP_PROXY} #{forward_to_host} #{forward_to_port} #{listen_port}], {}, logger)
      @socket_connector = SocketConnector.new("proxy #{listen_port} -> #{forward_to_host}:#{forward_to_port}", 'localhost', listen_port, 'unknown', logger)
    end

    def start
      @process.start
      @socket_connector.try_to_connect
    end

    def stop
      @process.stop
    end
  end
end
