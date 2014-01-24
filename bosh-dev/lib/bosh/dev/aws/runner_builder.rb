require 'bosh/dev/aws'
require 'bosh/dev/bat/director_address'
require 'bosh/dev/bosh_cli_session'
require 'bosh/stemcell/archive'
require 'bosh/dev/aws/micro_bosh_deployment_manifest'
require 'bosh/dev/aws/micro_bosh_deployment_cleaner'
require 'bosh/dev/aws/bat_deployment_manifest'
require 'bosh/dev/bat/runner'

module Bosh::Dev::Aws
  class RunnerBuilder
    def build(artifacts, net_type)
      env    = ENV
      logger = Logger.new(STDOUT)

      director_address = Bosh::Dev::Bat::DirectorAddress.resolved_from_env(env, 'BOSH_VPC_SUBDOMAIN')
      bosh_cli_session = Bosh::Dev::BoshCliSession.new
      stemcell_archive = Bosh::Stemcell::Archive.new(artifacts.bat_stemcell_path)

      microbosh_deployment_manifest =
        MicroBoshDeploymentManifest.new(env)
      microbosh_deployment_cleaner =
        MicroBoshDeploymentCleaner.new(microbosh_deployment_manifest)
      bat_deployment_manifest =
        BatDeploymentManifest.new(env, bosh_cli_session, stemcell_archive)

      # rubocop:disable ParameterLists
      Bosh::Dev::Bat::Runner.new(
        env, artifacts, director_address,
        bosh_cli_session, stemcell_archive,
        microbosh_deployment_manifest, bat_deployment_manifest,
        microbosh_deployment_cleaner, logger)
      # rubocop:enable ParameterLists
    end
  end
end
