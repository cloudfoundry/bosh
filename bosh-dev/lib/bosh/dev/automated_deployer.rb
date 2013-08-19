require 'bosh/dev/bosh_cli_session'
require 'bosh/dev/artifacts_downloader'
require 'bosh/dev/aws/deployments_repository'

module Bosh::Dev
  class AutomatedDeployer
    def initialize(options = {})
      @target = options.fetch(:target)
      @username = options.fetch(:username)
      @password = options.fetch(:password)
      @build_number = options.fetch(:build_number)
      @environment = options.fetch(:environment)

      @cli = options.fetch(:cli) { BoshCliSession.new }
      @artifacts_downloader = options.fetch(:artifacts_downloader) { ArtifactsDownloader.new }
      @deployments_repository = options.fetch(:deployments_repository) { Aws::DeploymentsRepository.new(path_root: '/tmp') }
    end

    def deploy
      manifest_path = File.join(deployments_repository.path, environment, 'deployments/bosh/bosh.yml')

      stemcell_path = artifacts_downloader.download_stemcell(build_number)
      release_path = artifacts_downloader.download_release(build_number)

      deployments_repository.clone_or_update!

      cli.run_bosh("target #{target}")
      cli.run_bosh("login #{username} #{password}")
      cli.run_bosh("deployment #{manifest_path}")
      cli.run_bosh("upload stemcell #{stemcell_path}", ignore_failures: true)
      cli.run_bosh("upload release #{release_path}", ignore_failures: true)
      cli.run_bosh('deploy', debug_on_fail: true)
    end

    private

    attr_reader :target, :username, :password, :cli, :artifacts_downloader, :build_number, :environment, :deployments_repository

  end
end