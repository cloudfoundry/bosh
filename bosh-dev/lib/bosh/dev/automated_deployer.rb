require 'bosh/core/shell'
require 'bosh/dev/bosh_cli_session'
require 'bosh/dev/director_client'
require 'bosh/dev/artifacts_downloader'
require 'bosh/dev/aws/deployments_repository'

module Bosh::Dev
  class AutomatedDeployer
    def initialize(options = {})
      @micro_target = options.fetch(:micro_target)
      @bosh_target = options.fetch(:bosh_target)
      @build_number = options.fetch(:build_number)
      @environment = options.fetch(:environment)

      @shell = options.fetch(:shell) { Bosh::Core::Shell.new }
      @artifacts_downloader = options.fetch(:artifacts_downloader) { ArtifactsDownloader.new }
      @deployments_repository = options.fetch(:deployments_repository) { Aws::DeploymentsRepository.new(path_root: '/tmp') }

      deployments_repository.clone_or_update!

      @micro_director_client = DirectorClient.new(uri: micro_target, username: deployment_bosh_user, password: deployment_bosh_password)
      @bosh_director_client = DirectorClient.new(uri: bosh_target, username: deployment_bosh_user, password: deployment_bosh_password)
    end

    def deploy
      stemcell_path = artifacts_downloader.download_stemcell(build_number)
      stemcell_archive = Bosh::Stemcell::Archive.new(stemcell_path)
      micro_director_client.upload_stemcell(stemcell_archive)

      release_path = artifacts_downloader.download_release(build_number)
      micro_director_client.upload_release(release_path)

      manifest_path = deployment_manifest_path
      micro_director_client.deploy(manifest_path)

      bosh_director_client.upload_stemcell(stemcell_archive)
    end

    private

    attr_reader :micro_target,
                :bosh_target,
                :artifacts_downloader,
                :build_number,
                :environment,
                :deployments_repository,
                :shell,
                :micro_director_client,
                :bosh_director_client

    def deployment_manifest_path
      @deployment_manifest_path ||= File.join(deployments_repository.path, environment, 'deployments/bosh/bosh.yml')
    end

    def deployment_bosh_user
      @deployment_bosh_user ||= shell.run(". #{deployment_bosh_environment_path} && echo $BOSH_USER").chomp
    end

    def deployment_bosh_password
      @deployment_bosh_password ||= shell.run(". #{deployment_bosh_environment_path} && echo $BOSH_PASSWORD").chomp
    end

    def deployment_bosh_environment_path
      File.join(deployments_repository.path, environment, 'bosh_environment')
    end
  end
end
