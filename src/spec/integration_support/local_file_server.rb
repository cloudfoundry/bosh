require 'puma'
require 'puma/configuration'
require 'puma/rack/builder'
require 'integration_support/service'
require 'integration_support/socket_connector'

module IntegrationSupport
  class LocalFileServer
    def initialize(directory, port, logger)
      @port = port
      @logger = logger

      builder =
        Puma::Rack::Builder.app do
          use Rack::CommonLogger
          use Rack::ShowExceptions
          run Rack::Directory.new(directory)

          map '/redirect/to' do
            run Proc.new { |env| [302, { 'Location' => env['QUERY_STRING'] }, []] }
          end
        end

      puma_configuration =
        Puma::Configuration.new do |user_config|
          user_config.tag 'local-file-server'
          user_config.bind "tcp://localhost:#{port}"
          user_config.app builder
        end

      @server_thread = Thread.new do
        begin
          Puma::Launcher.new(puma_configuration, log_writer: Puma::LogWriter.null).run
        rescue Interrupt
          # that's ok, the spec is done with us...
        end
      end

      @socket_connector = IntegrationSupport::SocketConnector.new(
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
