module Bosh::Director::ConfigServer
  class ClientFactory

    # @param logger Logger
    # @return ClientFactory
    def self.create(logger)
      director_name = Bosh::Director::Config.name
      config_server_enabled = Bosh::Director::Config.config_server_enabled

      new(director_name, config_server_enabled, logger)
    end

    # @param config_server_enabled True or False
    # @param logger Logger
    def initialize(director_name, config_server_enabled, logger)
      @director_name = director_name
      @config_server_enabled = config_server_enabled
      @logger = logger
    end

    def self.create_default_client
      create(Bosh::Director::Config.logger).create_client
    end

    def create_client
      if @config_server_enabled
        auth_http_client = AuthHTTPClient.new
        retryable_http_client = RetryableHTTPClient.new(auth_http_client)
        config_server_http_client = ConfigServerEnabledHTTPClient.new(retryable_http_client)
      else
        config_server_http_client = ConfigServerDisabledHTTPClient.new
      end

      ConfigServerClient.new(config_server_http_client, @director_name, @logger)
    end
  end
end
