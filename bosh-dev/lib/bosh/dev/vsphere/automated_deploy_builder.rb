require 'bosh/dev/vsphere'
require 'bosh/dev/automated_deployer'
require 'bosh/dev/artifacts_downloader'
require 'bosh/dev/deployments_repository'
require 'bosh/dev/vsphere/deployment_account'

module Bosh::Dev::VSphere
  class AutomatedDeployBuilder
    # rubocop:disable ParameterLists
    def build(build_number, infrastructure, operating_system, micro_target, bosh_target, environment_name, deployment_name)
      logger = Logger.new(STDERR)

      deployments_repository = Bosh::Dev::DeploymentsRepository.new(ENV, path_root: '/tmp')
      deployment_account = DeploymentAccount.new(
        environment_name, deployment_name, deployments_repository)

      download_adapter = Bosh::Dev::DownloadAdapter.new(logger)
      artifacts_downloader = Bosh::Dev::ArtifactsDownloader.new(download_adapter, logger)

      Bosh::Dev::AutomatedDeployer.new(
        build_number,
        infrastructure,
        operating_system,
        micro_target,
        bosh_target,
        deployment_account,
        artifacts_downloader,
      )
    end
    # rubocop:enable ParameterLists
  end
end
