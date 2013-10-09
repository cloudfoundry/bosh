require 'bosh/dev/bosh_cli_session'
require 'bosh/dev/director_client'
require 'bosh/dev/artifacts_downloader'
require 'bosh/dev/aws/deployment_account'
require 'bosh/dev/aws/deployments_repository'
require 'bosh/stemcell/archive'

module Bosh::Dev
  class AutomatedDeployer
    def self.for_environment(micro_target, bosh_target, build_number, environment)
      deployments_repository = Aws::DeploymentsRepository.new(ENV, path_root: '/tmp')
      deployment_account = Aws::DeploymentAccount.new(environment, deployments_repository)
      new(
        micro_target,
        bosh_target,
        build_number,
        deployment_account,
        ArtifactsDownloader.new,
      )
    end

    def initialize(micro_target, bosh_target, build_number, deployment_account, artifacts_downloader)
      @micro_target = micro_target
      @bosh_target = bosh_target
      @build_number = build_number
      @deployment_account = deployment_account
      @artifacts_downloader = artifacts_downloader
    end

    def deploy
      stemcell_path = artifacts_downloader.download_stemcell(build_number)
      stemcell_archive = Bosh::Stemcell::Archive.new(stemcell_path)
      micro_director_client.upload_stemcell(stemcell_archive)

      release_path = artifacts_downloader.download_release(build_number)
      micro_director_client.upload_release(release_path)

      manifest_path = deployment_account.manifest_path
      micro_director_client.deploy(manifest_path)

      bosh_director_client.upload_stemcell(stemcell_archive)
    end

    private

    attr_reader(
      :micro_target,
      :bosh_target,
      :build_number,
      :deployment_account,
      :artifacts_downloader,
    )

    def micro_director_client
      @micro_director_client ||= DirectorClient.new(
        uri: micro_target,
        username: deployment_account.bosh_user,
        password: deployment_account.bosh_password
      )
    end

    def bosh_director_client
      @director_client ||= DirectorClient.new(
        uri: bosh_target,
        username: deployment_account.bosh_user,
        password: deployment_account.bosh_password
      )
    end
  end
end
