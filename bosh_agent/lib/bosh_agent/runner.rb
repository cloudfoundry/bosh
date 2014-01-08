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

      @logger.info('Configuring agent...')
      Bootstrap.new.configure

      if Config.configure
        Monit.enable
        Monit.start
        Monit.start_services
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
