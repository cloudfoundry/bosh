# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AwsRegistry
  class Runner
    include YamlHelper

    def initialize(config_file)
      Bosh::AwsRegistry.configure(load_yaml_file(config_file))

      @logger = Bosh::AwsRegistry.logger
      @http_port = Bosh::AwsRegistry.http_port
      @http_user = Bosh::AwsRegistry.http_user
      @http_password = Bosh::AwsRegistry.http_password
    end

    def run
      @logger.info("BOSH AWS Registry starting...")
      EM.kqueue if EM.kqueue?
      EM.epoll if EM.epoll?

      EM.error_handler { |e| handle_em_error(e) }

      EM.run do
        start_http_server
      end
    end

    def stop
      @logger.info("BOSH AWS Registry shutting down...")
      @http_server.stop! if @http_server
      EM.stop
    end

    def start_http_server
      @logger.info "HTTP server is starting on port #{@http_port}..."
      @http_server = Thin::Server.new("0.0.0.0", @http_port, :signals => false) do
        Thin::Logging.silent = true
        map "/" do
          run Bosh::AwsRegistry::ApiController.new
        end
      end
      @http_server.start!
    end

    private

    def handle_em_error(e)
      @logger.send(level, e.to_s)
      if e.respond_to?(:backtrace) && e.backtrace.respond_to?(:join)
        @logger.send(level, e.backtrace.join("\n"))
      end
      stop
    end

  end
end
