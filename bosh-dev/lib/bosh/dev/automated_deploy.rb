require 'bosh/stemcell/archive'
require 'bosh/dev/build_target'
require 'bosh/dev/bosh_cli_session'
require 'bosh/dev/director_client'
require 'bosh/dev/micro_client'
require 'bosh/dev/aws/automated_deploy_builder'
require 'bosh/dev/vsphere/automated_deploy_builder'

module Bosh::Dev
  class AutomatedDeploy
    def self.for_rake_args(args)
      build_target = BuildTarget.from_names(
        args.build_number,
        args.infrastructure_name,
        args.operating_system_name,
        args.operating_system_version,
        args.agent_name,
      )

      builder = builder_for_infrastructure_name(args.infrastructure_name)
      builder.build(build_target, args.environment_name, args.deployment_name)
    end

    def self.builder_for_infrastructure_name(name)
      { 'aws'     => Bosh::Dev::Aws::AutomatedDeployBuilder.new,
        'vsphere' => Bosh::Dev::VSphere::AutomatedDeployBuilder.new,
      }[name]
    end

    def initialize(build_target, deployment_account, artifacts_downloader)
      @build_target = build_target
      @deployment_account = deployment_account
      @artifacts_downloader = artifacts_downloader
    end

    def deploy(bosh_target)
      @deployment_account.prepare

      director_client = DirectorClient.new(
        uri: bosh_target,
        username: @deployment_account.bosh_user,
        password: @deployment_account.bosh_password,
      )

      stemcell_archive = download_stemcell_archive
      director_client.upload_stemcell(stemcell_archive)

      release_path = @artifacts_downloader.download_release(@build_target.build_number, Dir.pwd)
      director_client.upload_release(release_path)

      manifest_path = @deployment_account.manifest_path
      director_client.deploy(manifest_path)

      director_client.clean_up
    end

    def deploy_micro
      @deployment_account.prepare

      micro_client = MicroClient.new

      manifest_path = @deployment_account.manifest_path
      stemcell_archive = download_stemcell_archive
      micro_client.deploy(manifest_path, stemcell_archive)

      # There is no clean up stage for micro deployment

      # micro bosh leaves receipt file for created bosh vms
      # which is needed to do further updates.
      @deployment_account.save
    end

    private

    def download_stemcell_archive
      stemcell_path = @artifacts_downloader.download_stemcell(@build_target, Dir.pwd)
      Bosh::Stemcell::Archive.new(stemcell_path)
    end
  end
end
