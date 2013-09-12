module Bosh::Agent
  class Runner
    def self.run(options)
      Config.setup(options)
      Runner.new.start
    end

    def initialize
      @logger = Config.logger
    end

    def start
      $stdout.sync = true
      @logger.info("Starting agent #{VERSION}...")

      if Config.configure
        @logger.info('Configuring agent...')
        Bootstrap.new.configure

        Monit.enable
        Monit.start
        Monit.start_services
      else
        @logger.info("Skipping configuration step (use '-c' argument to configure on start) ")
      end

      if Config.mbus.start_with?('https')
        @logger.info('Starting up https agent')
        require 'bosh_agent/http_handler'
        HTTPHandler.start
      else
        Handler.start
      end
    end
  end
end
