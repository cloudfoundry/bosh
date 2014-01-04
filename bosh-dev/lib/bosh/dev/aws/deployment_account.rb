require 'bosh/core/shell'

module Bosh::Dev::Aws
  # Requires folder structure:
  #   ...repo/<env-name>/bosh_environment
  #   ...repo/<env-name>/deployments/<deployment-name>/manifest.yml
  class DeploymentAccount
    def initialize(environment_name, deployment_name, deployments_repository)
      @environment_name = environment_name
      @deployment_name = deployment_name
      @deployments_repository = deployments_repository

      @bosh_environment_path = File.join(deployments_repository.path, environment_name, 'bosh_environment')
      @shell = Bosh::Core::Shell.new
      deployments_repository.clone_or_update!
    end

    def manifest_path
      @manifest_path ||= File.join(
        @deployments_repository.path,
        @environment_name,
        "deployments/#{@deployment_name}/manifest.yml",
      )
    end

    def bosh_user
      @bosh_user ||= @shell.run(". #{@bosh_environment_path} && echo $BOSH_USER").chomp
    end

    def bosh_password
      @bosh_password ||= @shell.run(". #{@bosh_environment_path} && echo $BOSH_PASSWORD").chomp
    end

    def prepare
      @shell.run(". #{@bosh_environment_path} && bosh aws create --trace")
      @deployments_repository.push
    end
  end
end
