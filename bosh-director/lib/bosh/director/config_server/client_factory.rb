module Bosh::Director::ConfigServer
  class ClientFactory

    # @param logger Logger
    # @return ClientFactory
    def self.create(logger)
      config_server_enabled = Bosh::Director::Config.config_server_enabled

      new(
        config_server_enabled,
        logger
      )
    end

    # @param config_server_enabled True or False
    # @param logger Logger
    def initialize(config_server_enabled, logger)
      @config_server_enabled = config_server_enabled
      @logger = logger
    end

    def create_client
      if @config_server_enabled
        EnabledClient.new(HTTPClient.new, @logger)
      else
        DisabledClient.new
      end
    end
  end
end
