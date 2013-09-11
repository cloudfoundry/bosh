module Bosh::Agent
  class Runner < Struct.new(:config)
    def self.run(options)
      Runner.new(options).start
    end

    def initialize(options)
      self.config = Bosh::Agent::Config.setup(options)
      @logger     = Bosh::Agent::Config.logger
    end

    def start
      $stdout.sync = true
      @logger.info("Starting agent #{Bosh::Agent::VERSION}...")

      if Config.configure
        @logger.info('Configuring agent...')
        # FIXME: this should not use message handler.
        # The whole thing should be refactored so that
        # regular code doesn't use RPC handlers other than
        # for responding to RPC.
        Bosh::Agent::Bootstrap.new.configure

        Bosh::Agent::Monit.enable
        Bosh::Agent::Monit.start
        Bosh::Agent::Monit.start_services
      else
        @logger.info("Skipping configuration step (use '-c' argument to configure on start) ")
      end

      if Config.mbus.start_with?('https')
        @logger.info('Starting up https agent')
        require 'bosh_agent/http_handler'
        Bosh::Agent::HTTPHandler.start
      else
        Bosh::Agent::Handler.start
      end
    end
  end
end
