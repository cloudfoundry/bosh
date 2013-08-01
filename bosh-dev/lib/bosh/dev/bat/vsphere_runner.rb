require 'bosh/dev/bat'
require 'bosh/dev/bat_helper'
require 'bosh/dev/bat/bosh_cli_session'
require 'bosh/dev/bat/stemcell_archive'
require 'bosh/dev/vsphere/bat_deployment_manifest'
require 'bosh/dev/vsphere/micro_bosh_deployment_manifest'

module Bosh::Dev::Bat
  class VsphereRunner
    def initialize
      @env = ENV.to_hash
      @bat_helper = Bosh::Dev::BatHelper.new('vsphere')
      @bosh_cli_session = Bosh::Dev::Bat::BoshCliSession.new
      @stemcell_archive = StemcellArchive.new(bat_helper.bosh_stemcell_path)
    end

    def deploy_micro
      Dir.chdir(bat_helper.micro_bosh_deployment_dir) do
        Bosh::Dev::VSphere::MicroBoshDeploymentManifest.new.write
      end

      Dir.chdir(bat_helper.artifacts_dir) do
        bosh_cli_session.run_bosh "micro deployment #{bat_helper.micro_bosh_deployment_name}"
        bosh_cli_session.run_bosh "micro deploy #{bat_helper.micro_bosh_stemcell_path}"
        bosh_cli_session.run_bosh 'login admin admin'

        bosh_cli_session.run_bosh "upload stemcell #{bat_helper.bosh_stemcell_path}", debug_on_fail: true

        bat_deployment_manifest = Bosh::Dev::VSphere::BatDeploymentManifest.new(director_uuid, stemcell_archive.version)
        bat_deployment_manifest.write
      end
    end

    def run_bats
      ENV['BAT_DEPLOYMENT_SPEC'] = File.join(bat_helper.artifacts_dir, 'bat.yml')
      ENV['BAT_DIRECTOR'] = director_ip
      ENV['BAT_DNS_HOST'] = director_ip
      ENV['BAT_STEMCELL'] = bat_helper.bosh_stemcell_path
      ENV['BAT_VCAP_PASSWORD'] = 'c1oudc0w'
      ENV['BAT_FAST'] = 'true'

      Rake::Task['bat'].invoke
    end

    def teardown_micro
      Dir.chdir(bat_helper.artifacts_dir) do
        bosh_cli_session.run_bosh 'delete deployment bat', ignore_failures: true
        bosh_cli_session.run_bosh "delete stemcell bosh-stemcell #{stemcell_archive.version}", ignore_failures: true
        bosh_cli_session.run_bosh 'micro delete', ignore_failures: true
      end
    end

    private

    attr_reader :env, :bat_helper, :bosh_cli_session, :stemcell_archive

    def director_ip
      env.fetch('BOSH_VSPHERE_MICROBOSH_IP')
    end

    def director_uuid
      status = bosh_cli_session.run_bosh 'status'

      matches =
        /
          UUID(\s)+
          (?<uuid>(\w+-)+\w+)
        /x.match(status)

      if matches
        matches[:uuid]
      end
    end
  end
end