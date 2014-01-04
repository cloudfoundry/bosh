require 'bosh/core/shell'

module Bosh::Dev::VSphere
  # Requires folder structure:
  #   ...repo/<env-name>/<deployment-name>/manifest.yml
  class DeploymentAccount
    attr_reader :bosh_user, :bosh_password

    def initialize(environment_name, deployment_name, deployments_repository)
      @environment_name = environment_name
      @deployment_name = deployment_name
      @deployments_repository = deployments_repository

      @bosh_user = 'admin'
      @bosh_password = 'admin'
    end

    def manifest_path
      @manifest_path ||= begin
        @deployments_repository.clone_or_update!
        File.join(
          @deployments_repository.path,
          @environment_name,
          @deployment_name,
          'manifest.yml',
        )
      end
    end

    def prepare
      # noop
    end
  end
end
