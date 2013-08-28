require 'cli/director'
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
      @cli = options.fetch(:cli) { BoshCliSession.new }
      @artifacts_downloader = options.fetch(:artifacts_downloader) { ArtifactsDownloader.new }
      @deployments_repository = options.fetch(:deployments_repository) { Aws::DeploymentsRepository.new(path_root: '/tmp') }
      @micro_director_client = options.fetch(:micro_director_client) { Bosh::Dev::DirectorClient.new(micro_target, username, password) }
      @bosh_director_client = options.fetch(:bosh_director_client) { Bosh::Dev::DirectorClient.new(bosh_target, username, password) }
    end

    def deploy
      manifest_path = File.join(deployments_repository.path, environment, 'deployments/bosh/bosh.yml')

      stemcell_path = artifacts_downloader.download_stemcell(build_number)
      release_path = artifacts_downloader.download_release(build_number)

      deployments_repository.clone_or_update!

      archive = Bosh::Stemcell::Archive.new(stemcell_path)
      deploy_to_micro(manifest_path, release_path, archive)

      upload_stemcell_to_bosh_director(archive)
    end

    private
    def upload_stemcell_to_bosh_director(archive)
      cli.run_bosh("target #{bosh_target}")
      cli.run_bosh("login #{username} #{password}")
      cli.run_bosh("upload stemcell #{archive.path}", debug_on_fail: true) unless bosh_director_client.has_stemcell?(archive.name, archive.version)
    end

    def deploy_to_micro(manifest_path, release_path, archive)
      cli.run_bosh("target #{micro_target}")
      cli.run_bosh("login #{username} #{password}")
      cli.run_bosh("deployment #{manifest_path}")
      cli.run_bosh("upload stemcell #{archive.path}", debug_on_fail: true) unless micro_director_client.has_stemcell?(archive.name, archive.version)

      cli.run_bosh("upload release #{release_path} --rebase", debug_on_fail: true)
      cli.run_bosh('deploy', debug_on_fail: true)
    end

    attr_reader :micro_target, :bosh_target, :cli, :artifacts_downloader, :build_number, :environment, :deployments_repository, :shell, :micro_director_client, :bosh_director_client

    def username
      @username ||= shell.run(". #{bosh_environment_path} && echo $BOSH_USER").chomp
    end

    def password
      @password ||= shell.run(". #{bosh_environment_path} && echo $BOSH_PASSWORD").chomp
    end

    def bosh_environment_path
      File.join(deployments_repository.path, environment, 'bosh_environment')
    end

  end
end
