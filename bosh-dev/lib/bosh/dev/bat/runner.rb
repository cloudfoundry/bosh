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
      bat_deployment_manifest,
      microbosh_deployment_cleaner,
      logger
    )
    # rubocop:enable ParameterLists
      @env                           = env
      @bat_helper                    = bat_helper
      @director_address              = director_address
      @bosh_cli_session              = bosh_cli_session
      @stemcell_archive              = stemcell_archive
      @microbosh_deployment_manifest = microbosh_deployment_manifest
      @bat_deployment_manifest       = bat_deployment_manifest
      @microbosh_deployment_cleaner  = microbosh_deployment_cleaner
      @logger                        = logger
    end

    def deploy_microbosh_and_run_bats
      @logger.info('Creating microbosh manifest')
      create_microbosh_manifest

      @logger.info('Cleaning microbosh deployment')
      @microbosh_deployment_cleaner.clean

      @logger.info('Deploying microbosh')
      deploy_microbosh

      @logger.info('Running bats')
      run_bats

      # We are not deleting micro here because
      # bats environment (vms) is cleaned before each run
      # by the micro_bosh_deployment_cleaner.
      # It's useful to keep around micro if tests
      # failed so we can debug problem(s).
    end

    def run_bats
      @logger.info('Targetting microbosh')
      target_micro

      @logger.info('Creating bat manifest')
      create_bat_manifest

      @logger.info('Setting ENV variables')
      set_bat_env_variables

      @logger.info('Running bat rake task')
      Rake::Task['bat'].invoke
    end

    private

    def target_micro
      username = @env['BOSH_USER'] || 'admin'
      password = @env['BOSH_PASSWORD'] || 'admin'
      @bosh_cli_session.run_bosh("-u #{username} -p #{password} target #{@director_address.hostname}")
    end

    def create_microbosh_manifest
      Dir.chdir(@bat_helper.micro_bosh_deployment_dir) do
        @microbosh_deployment_manifest.write
      end
    end

    def deploy_microbosh
      Dir.chdir(@bat_helper.artifacts_dir) do
        @bosh_cli_session.run_bosh("micro deployment #{@bat_helper.micro_bosh_deployment_name}")

        @logger.info('Running micro deploy')
        @bosh_cli_session.run_bosh("micro deploy #{@bat_helper.bosh_stemcell_path}")
        @bosh_cli_session.run_bosh('login admin admin')
      end
    end

    def create_bat_manifest
      Dir.chdir(@bat_helper.artifacts_dir) do
        @bat_deployment_manifest.write
      end
    end

    def set_bat_env_variables
      @env['BAT_DEPLOYMENT_SPEC']  = File.join(@bat_helper.artifacts_dir, 'bat.yml')
      @env['BAT_DIRECTOR']         = @director_address.hostname
      @env['BAT_DNS_HOST']         = @director_address.ip
      @env['BAT_STEMCELL']         = @bat_helper.bosh_stemcell_path
      @env['BAT_VCAP_PRIVATE_KEY'] = @env['BOSH_OPENSTACK_PRIVATE_KEY'] || @env['BOSH_KEY_PATH']
      @env['BAT_VCAP_PASSWORD']    = 'c1oudc0w'
      @env['BAT_INFRASTRUCTURE']   = @stemcell_archive.infrastructure
    end
  end
end
