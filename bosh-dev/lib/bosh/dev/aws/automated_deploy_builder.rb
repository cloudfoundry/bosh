require 'logger'
require 'bosh/dev/aws'
require 'bosh/dev/download_adapter'
require 'bosh/dev/automated_deploy'
require 'bosh/dev/artifacts_downloader'
require 'bosh/dev/deployments_repository'
require 'bosh/dev/aws/deployment_account'

module Bosh::Dev::Aws
  class AutomatedDeployBuilder
    def build(build_target, bosh_target, environment_name, deployment_name)
      logger = Logger.new(STDERR)

      deployments_repository = Bosh::Dev::DeploymentsRepository.new(ENV, path_root: '/tmp')
      deployment_account = DeploymentAccount.new(environment_name, deployment_name, deployments_repository)

      download_adapter = Bosh::Dev::DownloadAdapter.new(logger)
      artifacts_downloader = Bosh::Dev::ArtifactsDownloader.new(download_adapter, logger)

      Bosh::Dev::AutomatedDeploy.new(
        build_target,
        bosh_target,
        deployment_account,
        artifacts_downloader,
      )
    end
  end
end
