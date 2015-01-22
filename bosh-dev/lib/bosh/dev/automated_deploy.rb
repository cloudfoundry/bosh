require 'bosh/stemcell/archive'
require 'bosh/dev/director_client'
require 'bosh/dev/micro_client'
require 'bosh/stemcell/stemcell'

module Bosh::Dev
  class AutomatedDeploy
    def initialize(stemcell, deployment_account, artifacts_downloader, bosh_cli_session)
      @stemcell = stemcell
      @deployment_account = deployment_account
      @artifacts_downloader = artifacts_downloader
      @bosh_cli_session = bosh_cli_session
    end

    def deploy(bosh_target)
      @deployment_account.prepare

      director_client = DirectorClient.new(
        bosh_target,
        @deployment_account.bosh_user,
        @deployment_account.bosh_password,
        @bosh_cli_session,
      )

      stemcell_archive = download_stemcell_archive
      director_client.upload_stemcell(stemcell_archive)

      release_path = @artifacts_downloader.download_release(@stemcell.version, Dir.pwd)
      director_client.upload_release(release_path)

      manifest_path = @deployment_account.manifest_path
      director_client.deploy(manifest_path)
      director_client.clean_up
    ensure
      @bosh_cli_session.close
    end

    def deploy_micro
      @deployment_account.prepare

      micro_client = MicroClient.new(@bosh_cli_session)

      manifest_path = @deployment_account.manifest_path
      stemcell_archive = download_stemcell_archive
      micro_client.deploy(manifest_path, stemcell_archive)

      # There is no clean up stage for micro deployment

      # micro bosh leaves receipt file for created bosh vms
      # which is needed to do further updates.
      @deployment_account.save
    ensure
      @bosh_cli_session.close
    end

    private

    def download_stemcell_archive
      stemcell_path = @artifacts_downloader.download_stemcell(@stemcell, Dir.pwd)
      Bosh::Stemcell::Archive.new(stemcell_path)
    end
  end
end
