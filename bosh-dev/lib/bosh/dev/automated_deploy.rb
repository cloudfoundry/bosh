require 'bosh/stemcell/archive'
require 'bosh/dev/build_target'
require 'bosh/dev/bosh_cli_session'
require 'bosh/dev/director_client'
require 'bosh/dev/aws/automated_deploy_builder'
require 'bosh/dev/vsphere/automated_deploy_builder'

module Bosh::Dev
  class AutomatedDeploy
    def self.for_rake_args(args)
      build_target = BuildTarget.from_names(
        args.build_number,
        args.infrastructure_name,
        args.operating_system_name,
      )

      builder = builder_for_infrastructure_name(args.infrastructure_name)
      builder.build(
        build_target,
        args.bosh_target,
        args.environment_name,
        args.deployment_name,
      )
    end

    def self.builder_for_infrastructure_name(name)
      { 'aws'     => Bosh::Dev::Aws::AutomatedDeployBuilder.new,
        'vsphere' => Bosh::Dev::VSphere::AutomatedDeployBuilder.new,
      }[name]
    end

    def initialize(build_target, bosh_target, deployment_account, artifacts_downloader)
      @build_target = build_target
      @bosh_target = bosh_target
      @deployment_account = deployment_account
      @artifacts_downloader = artifacts_downloader
    end

    def deploy
      @deployment_account.prepare

      stemcell_path = @artifacts_downloader.download_stemcell(@build_target, Dir.pwd)
      stemcell_archive = Bosh::Stemcell::Archive.new(stemcell_path)
      director_client.upload_stemcell(stemcell_archive)

      release_path = @artifacts_downloader.download_release(@build_target.build_number, Dir.pwd)
      director_client.upload_release(release_path)

      manifest_path = @deployment_account.manifest_path
      director_client.deploy(manifest_path)
    end

    private

    def director_client
      @director_client ||= DirectorClient.new(
        uri: @bosh_target,
        username: @deployment_account.bosh_user,
        password: @deployment_account.bosh_password,
      )
    end
  end
end
