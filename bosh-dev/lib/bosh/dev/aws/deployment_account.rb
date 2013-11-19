require 'bosh/core/shell'

module Bosh::Dev::Aws
  class DeploymentAccount
    def initialize(deployment_name, deployments_repository)
      @deployment_name = deployment_name
      @deployments_repository = deployments_repository
      @shell = Bosh::Core::Shell.new
      deployments_repository.clone_or_update!
    end

    def manifest_path
      @manifest_path ||= File.join(deployments_repository.path, deployment_name, 'deployments/bosh/bosh.yml')
    end

    def bosh_user
      @bosh_user ||= shell.run(". #{deployment_bosh_environment_path} && echo $BOSH_USER").chomp
    end

    def bosh_password
      @bosh_password ||= shell.run(". #{deployment_bosh_environment_path} && echo $BOSH_PASSWORD").chomp
    end

    def prepare
      shell.run(". #{deployment_bosh_environment_path} && bosh aws create --trace")
      deployments_repository.push
    end

    private

    attr_reader :deployment_name, :shell, :deployments_repository

    def deployment_bosh_environment_path
      File.join(deployments_repository.path, deployment_name, 'bosh_environment')
    end
  end
end
