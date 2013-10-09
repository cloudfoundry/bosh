require 'bosh/dev/aws'
require 'bosh/dev/bat/director_address'
require 'bosh/dev/bosh_cli_session'
require 'bosh/stemcell/archive'
require 'bosh/dev/aws/micro_bosh_deployment_manifest'
require 'bosh/dev/aws/bat_deployment_manifest'
require 'bosh/dev/bat/runner'

module Bosh::Dev::Aws
  class RunnerBuilder
    def build(bat_helper, net_type)
      env              = ENV
      director_address = Bosh::Dev::Bat::DirectorAddress.resolved_from_env(env, 'BOSH_VPC_SUBDOMAIN')
      bosh_cli_session = Bosh::Dev::BoshCliSession.new
      stemcell_archive = Bosh::Stemcell::Archive.new(bat_helper.bosh_stemcell_path)

      microbosh_deployment_manifest =
        MicroBoshDeploymentManifest.new(env, bosh_cli_session)
      bat_deployment_manifest =
        BatDeploymentManifest.new(env, bosh_cli_session, stemcell_archive)

      # rubocop:disable ParameterLists
      Bosh::Dev::Bat::Runner.new(
        env, bat_helper, director_address, bosh_cli_session, stemcell_archive,
        microbosh_deployment_manifest, bat_deployment_manifest)
      # rubocop:enable ParameterLists
    end
  end
end
