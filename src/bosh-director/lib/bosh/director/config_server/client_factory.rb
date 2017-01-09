module Bosh::Director::ConfigServer
  class ClientFactory

    # @param logger Logger
    # @return ClientFactory
    def self.create(logger)
      director_name = Bosh::Director::Config.name
      config_server_enabled = Bosh::Director::Config.config_server_enabled

      new(
        director_name,
        config_server_enabled,
        logger
      )
    end

    # @param config_server_enabled True or False
    # @param logger Logger
    def initialize(director_name, config_server_enabled, logger)
      @director_name = director_name
      @config_server_enabled = config_server_enabled
      @logger = logger
    end

    def create_client(deployment_name = nil)
      if @config_server_enabled
        if deployment_name
          raise Bosh::Director::DeploymentNotFound, "no deployment found with name #{deployment_name}" unless Bosh::Director::Models::Deployment.find(name: deployment_name)
          EnabledClient.new(DeploymentHTTPClient.new(deployment_name, HTTPClient.new), @director_name, @logger)
        else
          EnabledClient.new(HTTPClient.new, @director_name, @logger)
        end
      else
        DisabledClient.new
      end
    end
  end
end
