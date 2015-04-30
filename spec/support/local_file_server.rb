require 'bosh/dev/sandbox/service'
require 'bosh/dev/sandbox/socket_connector'

module Bosh::Spec
  class LocalFileServer
    def initialize(directory, port, logger)
      @port = port
      @logger = logger

      builder = Rack::Builder.new do
        use Rack::CommonLogger
        use Rack::ShowExceptions
        run Rack::Directory.new(directory)

        map '/redirect/to' do
          run Proc.new { |env| [302, {'Location' => env['QUERY_STRING']}, []] }
        end
      end

      @server_thread = Thread.new do
        begin
          Rack::Handler::Thin.run builder, :Port => port
        rescue Interrupt
          # that's ok, the spec is done with us...
        end
      end

      @socket_connector = Bosh::Dev::Sandbox::SocketConnector.new(
        'local-file-server',
        'localhost',
        port,
        'unknown',
        logger,
      )
    end

    def start
      @socket_connector.try_to_connect
    end

    def stop
      @logger.info "Stopping file server..."
      @server_thread.raise Interrupt
      @server_thread.join
    end

    def http_url(path)
      "http://localhost:#{@port}/#{path}"
    end
  end
end
