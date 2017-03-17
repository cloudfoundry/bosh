module Bosh::Registry
  class Runner
    include YamlHelper

    def initialize(config_file)
      Bosh::Registry.configure(load_yaml_file(config_file))

      @logger = Bosh::Registry.logger
      @http_port = Bosh::Registry.http_port
      @http_user = Bosh::Registry.http_user
      @http_password = Bosh::Registry.http_password
    end

    def run
      @logger.info("BOSH Registry starting...")
      start_http_server
    end

    def stop
      @logger.info("BOSH Registry shutting down...")
      @http_server.stop! if @http_server
    end

    def start_http_server
      @logger.info "HTTP server is starting on port #{@http_port}..."
      @http_server = Thin::Server.new("0.0.0.0", @http_port, :signals => false) do
        Thin::Logging.silent = true
        map "/" do
          run Bosh::Registry::ApiController.new
        end
      end
      @http_server.start!
    end

    private

    def handle_em_error(e, level = :fatal)
      @logger.send(level, e.to_s)
      if e.respond_to?(:backtrace) && e.backtrace.respond_to?(:join)
        @logger.send(level, e.backtrace.join("\n"))
      end
      stop
    end

  end
end