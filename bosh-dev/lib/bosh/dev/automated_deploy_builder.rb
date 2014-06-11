require 'logger'
require 'bosh/dev/download_adapter'
require 'bosh/dev/artifacts_downloader'
require 'bosh/dev/deployments_repository'
require 'bosh/dev/aws/deployment_account'
require 'bosh/dev/vsphere/deployment_account'
require 'bosh/dev/vcloud/deployment_account'
require 'bosh/dev/automated_deploy'

module Bosh::Dev
  class AutomatedDeployBuilder
    def self.for_rake_args(args)
      build_target = BuildTarget.from_names(
        args.build_number,
        args.infrastructure_name,
        args.operating_system_name,
        args.operating_system_version,
        args.agent_name,
      )

      new(build_target, args.environment_name, args.deployment_name)
    end

    def initialize(build_target, environment_name, deployment_name)
      @build_target = build_target
      @environment_name = environment_name
      @deployment_name = deployment_name
    end

    def build
      deployments_repository = DeploymentsRepository.new(ENV)
      deployment_account = build_deployment_account(deployments_repository)

      logger = Logger.new(STDERR)
      download_adapter = DownloadAdapter.new(logger)
      artifacts_downloader = ArtifactsDownloader.new(download_adapter, logger)

      AutomatedDeploy.new(@build_target, deployment_account, artifacts_downloader)
    end

    private

    def build_deployment_account(deployments_repository)
      ns = {
        'aws'     => Bosh::Dev::Aws,
        'vsphere' => Bosh::Dev::VSphere,
        'vcloud'  => Bosh::Dev::VCloud,
      }[@build_target.infrastructure_name]

      ns::DeploymentAccount.new(@environment_name, @deployment_name, deployments_repository)
    end
  end
end
