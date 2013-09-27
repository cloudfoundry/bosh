require 'bosh/dev/vsphere'
require 'bosh/dev/bat_helper'
require 'bosh/dev/bat/director_address'
require 'bosh/dev/bat/director_uuid'
require 'bosh/dev/bosh_cli_session'
require 'bosh/stemcell/archive'
require 'bosh/dev/vsphere/micro_bosh_deployment_manifest'
require 'bosh/dev/vsphere/bat_deployment_manifest'
require 'bosh/dev/bat/runner'

module Bosh::Dev::VSphere
  class RunnerBuilder
    def build
      env              = ENV
      bat_helper       = Bosh::Dev::BatHelper.new('vsphere', :dont_care)
      director_address = Bosh::Dev::Bat::DirectorAddress.from_env(env, 'BOSH_VSPHERE_MICROBOSH_IP')
      bosh_cli_session = Bosh::Dev::BoshCliSession.new
      director_uuid    = Bosh::Dev::Bat::DirectorUuid.new(bosh_cli_session)
      stemcell_archive = Bosh::Stemcell::Archive.new(bat_helper.bosh_stemcell_path)

      microbosh_deployment_manifest =
        MicroBoshDeploymentManifest.new(env)
      bat_deployment_manifest =
        BatDeploymentManifest.new(env, director_uuid, stemcell_archive)

      # rubocop:disable ParameterLists
      Bosh::Dev::Bat::Runner.new(
        env, bat_helper, director_address, bosh_cli_session, stemcell_archive,
        microbosh_deployment_manifest, bat_deployment_manifest)
      # rubocop:enable ParameterLists
    end
  end
end
