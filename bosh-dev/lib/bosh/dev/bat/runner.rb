require 'resolv'
require 'bosh/dev/bat'

module Bosh::Dev::Bat
  class Runner
    # rubocop:disable ParameterLists
    def initialize(
      env,
      bat_helper,
      director_address,
      bosh_cli_session,
      stemcell_archive,
      microbosh_deployment_manifest,
      bat_deployment_manifest
    )
      @env                           = env
      @bat_helper                    = bat_helper
      @director_address              = director_address
      @bosh_cli_session              = bosh_cli_session
      @stemcell_archive              = stemcell_archive
      @microbosh_deployment_manifest = microbosh_deployment_manifest
      @bat_deployment_manifest       = bat_deployment_manifest
    end
    # rubocop:enable ParameterLists

    def run_bats
      prepare_microbosh
      prepare_bat_deployment
      Rake::Task['bat'].invoke
    ensure
      teardown_micro
    end

    private

    attr_reader(
      :env,
      :bat_helper,
      :director_address,
      :bosh_cli_session,
      :stemcell_archive,
      :microbosh_deployment_manifest,
      :bat_deployment_manifest
    )

    def create_microbosh_manifest
      Dir.chdir(bat_helper.micro_bosh_deployment_dir) do
        microbosh_deployment_manifest.write
      end
    end

    def prepare_microbosh
      create_microbosh_manifest
      Dir.chdir(bat_helper.artifacts_dir) do
        bosh_cli_session.run_bosh "micro deployment #{bat_helper.micro_bosh_deployment_name}"
        bosh_cli_session.run_bosh "micro deploy #{bat_helper.bosh_stemcell_path}"
        bosh_cli_session.run_bosh 'login admin admin'
        bosh_cli_session.run_bosh "upload stemcell #{bat_helper.bosh_stemcell_path}", debug_on_fail: true
      end
    end

    def create_bat_manifest
      Dir.chdir(bat_helper.artifacts_dir) do
        bat_deployment_manifest.write
      end
    end

    def prepare_bat_deployment
      create_bat_manifest
      env['BAT_DEPLOYMENT_SPEC'] = File.join(bat_helper.artifacts_dir, 'bat.yml')
      env['BAT_DIRECTOR']        = director_address.hostname
      env['BAT_DNS_HOST']        = director_address.ip
      env['BAT_STEMCELL']        = bat_helper.bosh_stemcell_path
      env['BAT_VCAP_PASSWORD']   = 'c1oudc0w'
      env['BAT_FAST']            = 'true'
    end

    def teardown_micro
      Dir.chdir(bat_helper.artifacts_dir) do
        bosh_cli_session.run_bosh 'delete deployment bat', ignore_failures: true
        bosh_cli_session.run_bosh "delete stemcell bosh-stemcell #{stemcell_archive.version}", ignore_failures: true
        bosh_cli_session.run_bosh 'micro delete', ignore_failures: true
      end
    end
  end
end
