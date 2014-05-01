require 'bosh/dev/vsphere'
require 'bosh/dev/automated_deploy'
require 'bosh/dev/artifacts_downloader'
require 'bosh/dev/deployments_repository'
require 'bosh/dev/vsphere/deployment_account'

module Bosh::Dev::VSphere
  class AutomatedDeployBuilder
    def build(build_target, environment_name, deployment_name)
      logger = Logger.new(STDERR)

      deployments_repository = Bosh::Dev::DeploymentsRepository.new(ENV)
      deployment_account = DeploymentAccount.new(environment_name, deployment_name, deployments_repository)

      download_adapter = Bosh::Dev::DownloadAdapter.new(logger)
      artifacts_downloader = Bosh::Dev::ArtifactsDownloader.new(download_adapter, logger)

      Bosh::Dev::AutomatedDeploy.new(
        build_target,
        deployment_account,
        artifacts_downloader,
      )
    end
  end
end
