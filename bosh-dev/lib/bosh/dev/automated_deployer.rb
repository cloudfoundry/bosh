require 'bosh/stemcell/archive'
require 'bosh/dev/bosh_cli_session'
require 'bosh/dev/director_client'
require 'bosh/dev/artifacts_downloader'
require 'bosh/dev/deployments_repository'
require 'bosh/dev/aws/deployment_account'

module Bosh::Dev
  class AutomatedDeployer
    def self.for_environment(micro_target, bosh_target, build_number, environment)
      deployments_repository = DeploymentsRepository.new(ENV, path_root: '/tmp')
      deployment_account = Aws::DeploymentAccount.new(environment, deployments_repository)
      new(
        micro_target,
        bosh_target,
        build_number,
        deployment_account,
        ArtifactsDownloader.new,
        deployments_repository
      )
    end

    # rubocop:disable ParameterLists
    def initialize(micro_target, bosh_target, build_number, deployment_account, artifacts_downloader,
      deployments_repository)
      @micro_target = micro_target
      @bosh_target = bosh_target
      @build_number = build_number
      @deployment_account = deployment_account
      @artifacts_downloader = artifacts_downloader
      @deployments_repository = deployments_repository
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

    def migrate
      deployment_account.run_with_env('bosh aws create --trace')
      deployments_repository.push
    end

    private

    attr_reader(
      :micro_target,
      :bosh_target,
      :build_number,
      :deployment_account,
      :artifacts_downloader,
      :deployments_repository,
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
