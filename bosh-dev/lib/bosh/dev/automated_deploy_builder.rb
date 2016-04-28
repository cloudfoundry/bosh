require 'bosh/dev/download_adapter'
require 'bosh/dev/artifacts_downloader'
require 'bosh/dev/deployments_repository'
require 'bosh/dev/aws/deployment_account'
require 'bosh/dev/vsphere/deployment_account'
require 'bosh/dev/vcloud/deployment_account'
require 'bosh/dev/automated_deploy'
require 'bosh/dev/uri_provider'
require 'bosh/dev/bosh_cli_session'
require 'bosh/stemcell/stemcell'
require 'bosh/stemcell/definition'
require 'logging'

module Bosh::Dev
  class AutomatedDeployBuilder
    def self.for_rake_args(args)
      definition = Bosh::Stemcell::Definition.for(
        args.infrastructure_name,
        args.hypervisor_name,
        args.operating_system_name,
        args.operating_system_version,
        args.agent_name,
        args.light == 'true',
      )
      stemcell = Bosh::Stemcell::Stemcell.new(definition, 'bosh-stemcell', args.build_number, args.disk_format)

      new(stemcell, args.environment_name, args.deployment_name)
    end

    def initialize(stemcell, environment_name, deployment_name)
      @stemcell = stemcell
      @environment_name = environment_name
      @deployment_name = deployment_name
    end

    def build
      logger = Logging.logger(STDERR)

      commit_message = 'Autodeployer updating deployment receipt for the next micro update (we use the repo to communicate between test runs)'
      deployments_repository = DeploymentsRepository.new(ENV, logger, commit_message: commit_message)
      deployment_account = build_deployment_account(deployments_repository)

      download_adapter = DownloadAdapter.new(logger)
      artifacts_downloader = ArtifactsDownloader.new(download_adapter, logger)

      # Configure to use real gems (not bundle exec)
      # to make sure bosh_cli/bosh_cli_plugin_micro actually work.
      bosh_cmd = Bosh::Dev::S3GemBoshCmd.new(@stemcell.version, logger)
      bosh_cli_session = Bosh::Dev::BoshCliSession.new(bosh_cmd)

      AutomatedDeploy.new(
        @stemcell,
        deployment_account,
        artifacts_downloader,
        bosh_cli_session,
      )
    end

    private

    def build_deployment_account(deployments_repository)
      ns = {
        'aws'     => Bosh::Dev::Aws,
        'vsphere' => Bosh::Dev::VSphere,
        'vcloud'  => Bosh::Dev::VCloud,
      }[@stemcell.infrastructure.name]

      ns::DeploymentAccount.new(@environment_name, @deployment_name, deployments_repository)
    end
  end
end
