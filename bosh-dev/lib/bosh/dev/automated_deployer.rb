require 'bosh/stemcell/archive'
require 'bosh/dev/bosh_cli_session'
require 'bosh/dev/director_client'
require 'bosh/dev/aws/automated_deploy_builder'
require 'bosh/dev/vsphere/automated_deploy_builder'

module Bosh::Dev
  class AutomatedDeployer
    def self.for_rake_args(args)
      builder = builder_for_infrastructure_name(args.infrastructure_name)
      builder.build(
        args.build_number,
        Bosh::Stemcell::Infrastructure.for(args.infrastructure_name),
        Bosh::Stemcell::OperatingSystem.for(args.operating_system_name),
        args.micro_target,
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

    # rubocop:disable ParameterLists
    def initialize(
      build_number,
      infrastructure,
      operating_system,
      micro_target,
      bosh_target,
      deployment_account,
      artifacts_downloader
    )
      @build_number = build_number
      @infrastructure = infrastructure
      @operating_system = operating_system
      @micro_target = micro_target
      @bosh_target = bosh_target
      @deployment_account = deployment_account
      @artifacts_downloader = artifacts_downloader
    end
    # rubocop:enable ParameterLists

    def deploy
      @deployment_account.prepare

      stemcell_path = @artifacts_downloader.download_stemcell(
        @build_number, @infrastructure, @operating_system, false, Dir.pwd)
      stemcell_archive = Bosh::Stemcell::Archive.new(stemcell_path)
      micro_director_client.upload_stemcell(stemcell_archive)

      release_path = @artifacts_downloader.download_release(@build_number, Dir.pwd)
      micro_director_client.upload_release(release_path)

      manifest_path = @deployment_account.manifest_path
      micro_director_client.deploy(manifest_path)

      bosh_director_client.upload_stemcell(stemcell_archive)
    end

    private

    def micro_director_client
      @micro_director_client ||= DirectorClient.new(
        uri: @micro_target,
        username: @deployment_account.bosh_user,
        password: @deployment_account.bosh_password,
      )
    end

    def bosh_director_client
      @director_client ||= DirectorClient.new(
        uri: @bosh_target,
        username: @deployment_account.bosh_user,
        password: @deployment_account.bosh_password,
      )
    end
  end
end
