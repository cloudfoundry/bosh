require 'bosh/dev/bosh_cli_session'
require 'bosh/dev/director_client'
require 'bosh/dev/artifacts_downloader'
require 'bosh/dev/aws/deployment_account'
require 'bosh/stemcell/archive'

module Bosh::Dev
  class AutomatedDeployer
    def initialize(options = {})
      @micro_target = options.fetch(:micro_target)
      @bosh_target = options.fetch(:bosh_target)
      @build_number = options.fetch(:build_number)
      @environment = options.fetch(:environment)

      @artifacts_downloader = options.fetch(:artifacts_downloader) { ArtifactsDownloader.new }
      @deployment_account = Aws::DeploymentAccount.new(options.fetch(:environment))

      @micro_director_client = DirectorClient.new(uri: micro_target, username: deployment_account.bosh_user, password: deployment_account.bosh_password)
      @bosh_director_client = DirectorClient.new(uri: bosh_target, username: deployment_account.bosh_user, password: deployment_account.bosh_password)
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

    attr_reader :micro_target,
                :bosh_target,
                :artifacts_downloader,
                :build_number,
                :environment,
                :deployment_account,
                :micro_director_client,
                :bosh_director_client
  end
end
