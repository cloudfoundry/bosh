require 'resolv'
require 'bosh/dev/bat'

module Bosh::Dev::Bat
  class Runner
    # rubocop:disable ParameterLists
    def initialize(
      env,
      artifacts,
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
      @artifacts                     = artifacts
      @director_address              = director_address
      @bosh_cli_session              = bosh_cli_session
      @stemcell_archive              = stemcell_archive
      @microbosh_deployment_manifest = microbosh_deployment_manifest
      @bat_deployment_manifest       = bat_deployment_manifest
      @microbosh_deployment_cleaner  = microbosh_deployment_cleaner
      @logger                        = logger
    end

    def deploy_bats_microbosh
      @logger.info('Creating microbosh manifest')
      create_microbosh_manifest

      @logger.info('Cleaning microbosh deployment')
      @microbosh_deployment_cleaner.clean

      @logger.info('Deploying microbosh')
      deploy_microbosh
    end

    def run_bats
      @logger.info('Running bats')

      @logger.info('Targeting microbosh')
      target_micro

      @logger.info('Creating bat manifest')
      create_bat_manifest

      @logger.info('Setting ENV variables')
      set_bat_env_variables

      @logger.info('Running bat rake task')
      Rake::Task['bat'].invoke
    end

    private

    attr_reader :artifacts

    def target_micro
      username = @env['BOSH_USER'] || 'admin'
      password = @env['BOSH_PASSWORD'] || 'admin'
      @bosh_cli_session.run_bosh("-u #{username} -p #{password} target #{@director_address.hostname}")
    end

    def create_microbosh_manifest
      Dir.chdir(artifacts.micro_bosh_deployment_dir) do
        @microbosh_deployment_manifest.write
      end
    end

    def deploy_microbosh
      Dir.chdir(artifacts.path) do
        @bosh_cli_session.run_bosh("micro deployment #{artifacts.micro_bosh_deployment_name}")

        @logger.info('Running micro deploy')
        @bosh_cli_session.run_bosh("micro deploy #{artifacts.stemcell_path}")
        @bosh_cli_session.run_bosh('login admin admin')
      end
    end

    def create_bat_manifest
      Dir.chdir(artifacts.path) do
        @bat_deployment_manifest.write
      end
    end

    def set_bat_env_variables
      @env['BAT_DEPLOYMENT_SPEC']  = File.join(artifacts.path, 'bat.yml')
      @env['BAT_DIRECTOR']         = @director_address.hostname
      @env['BAT_DNS_HOST']         = @director_address.ip
      @env['BAT_STEMCELL']         = artifacts.stemcell_path
      @env['BAT_VCAP_PRIVATE_KEY'] = @env['BOSH_OPENSTACK_PRIVATE_KEY'] || @env['BOSH_KEY_PATH']
      @env['BAT_VCAP_PASSWORD']    = 'c1oudc0w'
      @env['BAT_INFRASTRUCTURE']   = @stemcell_archive.infrastructure
      @env['BAT_NETWORKING']       = @bat_deployment_manifest.net_type
    end
  end
end
