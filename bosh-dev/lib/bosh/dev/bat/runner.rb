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
    # rubocop:enable ParameterLists
      @env                           = env
      @bat_helper                    = bat_helper
      @director_address              = director_address
      @bosh_cli_session              = bosh_cli_session
      @stemcell_archive              = stemcell_archive
      @microbosh_deployment_manifest = microbosh_deployment_manifest
      @bat_deployment_manifest       = bat_deployment_manifest
    end

    def deploy_microbosh_and_run_bats
      create_microbosh_manifest
      deploy_microbosh
      run_bats
    ensure
      teardown_micro
    end

    def run_bats
      create_bat_manifest
      set_bat_env_variables
      Rake::Task['bat'].invoke
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

    def deploy_microbosh
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

    def set_bat_env_variables
      env['BAT_DEPLOYMENT_SPEC']  = File.join(bat_helper.artifacts_dir, 'bat.yml')
      env['BAT_DIRECTOR']         = director_address.hostname
      env['BAT_DNS_HOST']         = director_address.ip
      env['BAT_STEMCELL']         = bat_helper.bosh_stemcell_path
      env['BAT_VCAP_PRIVATE_KEY'] = env['BOSH_OPENSTACK_PRIVATE_KEY']
      env['BAT_VCAP_PASSWORD']    = 'c1oudc0w'
      env['BAT_INFRASTRUCTURE']   = stemcell_archive.infrastructure
    end

    def teardown_micro
      Dir.chdir(bat_helper.artifacts_dir) do
        bosh_cli_session.run_bosh 'delete deployment bat', ignore_failures: true
        bosh_cli_session.run_bosh "delete stemcell #{stemcell_archive.name} #{stemcell_archive.version}", ignore_failures: true
        bosh_cli_session.run_bosh 'micro delete', ignore_failures: true
      end
    end
  end
end
