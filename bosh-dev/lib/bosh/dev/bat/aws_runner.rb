require 'resolv'
require 'bosh/dev/bat'
require 'bosh/dev/bat_helper'
require 'bosh/dev/bosh_cli_session'
require 'bosh/dev/bat/stemcell_archive'
require 'bosh/dev/aws/micro_bosh_deployment_manifest'
require 'bosh/dev/aws/bat_deployment_manifest'

module Bosh::Dev::Bat
  class AwsRunner
    def initialize
      @env = ENV.to_hash
      @bat_helper = Bosh::Dev::BatHelper.new('aws')
      @bosh_cli_session = Bosh::Dev::BoshCliSession.new
      @stemcell_archive = StemcellArchive.new(bat_helper.bosh_stemcell_path)
    end

    def run_bats
      prepare_microbosh

      prepare_bat_deployment

      Rake::Task['bat'].invoke
    ensure
      teardown_micro
    end

    private

    attr_reader :env, :bat_helper, :bosh_cli_session, :stemcell_archive

    def create_microbosh_manifest
      Dir.chdir(bat_helper.micro_bosh_deployment_dir) do
        Bosh::Dev::Aws::MicroBoshDeploymentManifest.new(bosh_cli_session).write
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
        bat_deployment_manifest = Bosh::Dev::Aws::BatDeploymentManifest.new(bosh_cli_session, stemcell_archive.version)
        bat_deployment_manifest.write
      end
    end

    def prepare_bat_deployment
      create_bat_manifest

      ENV['BAT_DEPLOYMENT_SPEC'] = File.join(bat_helper.artifacts_dir, 'bat.yml')
      ENV['BAT_DIRECTOR'] = director_hostname
      ENV['BAT_DNS_HOST'] = director_ip
      ENV['BAT_STEMCELL'] = bat_helper.bosh_stemcell_path
      ENV['BAT_VCAP_PASSWORD'] = 'c1oudc0w'
      ENV['BAT_FAST'] = 'true'
    end

    def teardown_micro
      Dir.chdir(bat_helper.artifacts_dir) do
        bosh_cli_session.run_bosh 'delete deployment bat', ignore_failures: true
        bosh_cli_session.run_bosh "delete stemcell bosh-stemcell #{stemcell_archive.version}", ignore_failures: true
        bosh_cli_session.run_bosh 'micro delete', ignore_failures: true
      end
    end

    def director_hostname
      "micro.#{env.fetch('BOSH_VPC_SUBDOMAIN')}.cf-app.com"
    end

    def director_ip
      Resolv.getaddress(director_hostname)
    end
  end
end
