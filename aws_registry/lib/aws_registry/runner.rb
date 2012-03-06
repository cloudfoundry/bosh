# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AWSRegistry
  class Runner
    include YamlHelper

    def initialize(config_file)
      Bosh::AWSRegistry.configure(load_yaml_file(config_file))

      @logger = Bosh::AWSRegistry.logger
      @http_port = Bosh::AWSRegistry.http_port
      @http_user = Bosh::AWSRegistry.http_user
      @http_password = Bosh::AWSRegistry.http_password
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
          run Bosh::AWSRegistry::ApiController.new
        end
      end
      @http_server.start!
    end

    private

    def handle_em_error(e)
      @shutting_down = true
      log_exception(e, :fatal)
      stop
    end

    def log_exception(e, level = :error)
      level = :error unless level == :fatal
      @logger.send(level, e.to_s)
      if e.respond_to?(:backtrace) && e.backtrace.respond_to?(:join)
        @logger.send(level, e.backtrace.join("\n"))
      end
    end

  end
end
