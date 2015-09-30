require 'bosh/dev/vsphere'
require 'bosh/dev/bat/director_address'
require 'bosh/dev/bat/director_uuid'
require 'bosh/dev/bosh_cli_session'
require 'bosh/stemcell/archive'
require 'bosh/dev/vsphere/micro_bosh_deployment_manifest'
require 'bosh/dev/vsphere/micro_bosh_deployment_cleaner'
require 'bosh/dev/bat/runner'
require 'logging'

module Bosh::Dev::VSphere
  class RunnerBuilder
    def build(artifacts, net_type)
      env    = ENV
      logger = Logging.logger(STDOUT)

      director_address = Bosh::Dev::Bat::DirectorAddress.from_env(env, 'BOSH_VSPHERE_MICROBOSH_IP')
      bosh_cli_session = Bosh::Dev::BoshCliSession.default
      director_uuid    = Bosh::Dev::Bat::DirectorUuid.new(bosh_cli_session)
      stemcell_archive = Bosh::Stemcell::Archive.new(artifacts.stemcell_path)

      microbosh_deployment_manifest =
        MicroBoshDeploymentManifest.new(env, net_type)

      bat_deployment_spec_path = env['BOSH_VSPHERE_BAT_DEPLOYMENT_SPEC']
      raise 'Missing env var: BOSH_VSPHERE_BAT_DEPLOYMENT_SPEC' unless bat_deployment_spec_path

      bat_deployment_manifest = Bosh::Dev::Bat::DeploymentManifest.load_from_file(bat_deployment_spec_path)
      bat_deployment_manifest.net_type = net_type
      bat_deployment_manifest.director_uuid = director_uuid
      bat_deployment_manifest.stemcell = stemcell_archive

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
