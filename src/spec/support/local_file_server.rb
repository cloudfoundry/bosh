require 'bosh/dev/sandbox/service'
require 'bosh/dev/sandbox/socket_connector'
require 'puma'
require 'puma/configuration'

module Bosh::Spec
  class LocalFileServer
    def initialize(directory, port, logger)
      @port = port
      @logger = logger

      builder = ::Puma::Rack::Builder.app do
        use Rack::CommonLogger
        use Rack::ShowExceptions
        run Rack::Directory.new(directory)

        map '/redirect/to' do
          run Proc.new { |env| [302, {'Location' => env['QUERY_STRING']}, []] }
        end
      end

      @server_thread = Thread.new do
        begin
          puma_configuration = ::Puma::Configuration.new do |user_config|
            user_config.tag 'local-file-server'
            user_config.bind "tcp://localhost:#{port}"
            user_config.app builder
          end
          puma_launcher = ::Puma::Launcher.new(puma_configuration)
          puma_launcher.run
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
