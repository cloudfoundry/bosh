require 'bosh/dev/vsphere'
require 'bosh/dev/bat/director_address'
require 'bosh/dev/bat/director_uuid'
require 'bosh/dev/bosh_cli_session'
require 'bosh/stemcell/archive'
require 'bosh/dev/vsphere/micro_bosh_deployment_manifest'
require 'bosh/dev/vsphere/micro_bosh_deployment_cleaner'
require 'bosh/dev/vsphere/bat_deployment_manifest'
require 'bosh/dev/bat/runner'

module Bosh::Dev::VSphere
  class RunnerBuilder
    def build(artifacts, net_type)
      env    = ENV
      logger = Logger.new(STDOUT)

      director_address = Bosh::Dev::Bat::DirectorAddress.from_env(env, 'BOSH_VSPHERE_MICROBOSH_IP')
      bosh_cli_session = Bosh::Dev::BoshCliSession.new
      director_uuid    = Bosh::Dev::Bat::DirectorUuid.new(bosh_cli_session)
      stemcell_archive = Bosh::Stemcell::Archive.new(artifacts.bat_stemcell_path)

      microbosh_deployment_manifest =
        MicroBoshDeploymentManifest.new(env)
      bat_deployment_manifest =
        BatDeploymentManifest.new(env, director_uuid, stemcell_archive)

      microbosh_deployment_cleaner = MicroBoshDeploymentCleaner.new(microbosh_deployment_manifest)

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
