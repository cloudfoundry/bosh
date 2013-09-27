require 'bosh/dev/openstack'
require 'bosh/dev/bat_helper'
require 'bosh/dev/bat/director_address'
require 'bosh/dev/bat/director_uuid'
require 'bosh/dev/bosh_cli_session'
require 'bosh/stemcell/archive'
require 'bosh/dev/openstack/micro_bosh_deployment_manifest'
require 'bosh/dev/openstack/bat_deployment_manifest'
require 'bosh/dev/bat/runner'

module Bosh::Dev::Openstack
  class RunnerBuilder
    def build(net_type)
      env              = ENV
      bat_helper       = Bosh::Dev::BatHelper.new('openstack', :dont_care)
      director_address = Bosh::Dev::Bat::DirectorAddress.from_env(env, 'BOSH_OPENSTACK_VIP_DIRECTOR_IP')
      bosh_cli_session = Bosh::Dev::BoshCliSession.new
      director_uuid    = Bosh::Dev::Bat::DirectorUuid.new(bosh_cli_session)
      stemcell_archive = Bosh::Stemcell::Archive.new(bat_helper.bosh_stemcell_path)

      microbosh_deployment_manifest =
        MicroBoshDeploymentManifest.new(env, net_type)
      bat_deployment_manifest =
        BatDeploymentManifest.new(env, net_type, director_uuid, stemcell_archive)

      # rubocop:disable ParameterLists
      Bosh::Dev::Bat::Runner.new(
        env, bat_helper, director_address, bosh_cli_session, stemcell_archive,
        microbosh_deployment_manifest, bat_deployment_manifest)
      # rubocop:enable ParameterLists
    end
  end
end
