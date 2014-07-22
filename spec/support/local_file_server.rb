require 'bosh/dev/sandbox/service'
require 'bosh/dev/sandbox/socket_connector'

module Bosh::Spec
  class LocalFileServer
    def initialize(directory, port, logger)
      @port = port

      @service = Bosh::Dev::Sandbox::Service.new(
        %W(rackup -p #{port} -b run(Rack::Directory.new('#{directory}'))),
        {},
        logger,
      )

      @socket_connector = Bosh::Dev::Sandbox::SocketConnector.new(
        'local-file-server',
        'localhost',
        port,
        logger,
      )
    end

    def start
      @service.start
      @socket_connector.try_to_connect
    end

    def stop
      @service.stop
    end

    def http_url(path)
      "http://localhost:#{@port}/#{path}"
    end
  end
end
