require 'bosh/dev/vsphere'
require 'bosh/dev/automated_deployer'
require 'bosh/dev/artifacts_downloader'
require 'bosh/dev/deployments_repository'
require 'bosh/dev/vsphere/deployment_account'

module Bosh::Dev::VSphere
  class AutomatedDeployBuilder
    def build(micro_target, bosh_target, build_number, environment_name, deployment_name)
      deployments_repository = Bosh::Dev::DeploymentsRepository.new(ENV, path_root: '/tmp')

      deployment_account = DeploymentAccount.new(
        environment_name, deployment_name, deployments_repository)

      Bosh::Dev::AutomatedDeployer.new(
        micro_target,
        bosh_target,
        build_number,
        deployment_account,
        Bosh::Dev::ArtifactsDownloader.new,
      )
    end
  end
end
