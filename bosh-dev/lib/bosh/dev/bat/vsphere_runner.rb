require 'bosh/dev/bat'
require 'bosh/dev/bat_helper'
require 'bosh/dev/bosh_cli_session'
require 'bosh/stemcell/archive'
require 'bosh/dev/vsphere/micro_bosh_deployment_manifest'
require 'bosh/dev/vsphere/bat_deployment_manifest'
require 'bosh/dev/bat/director_address'

module Bosh::Dev::Bat
  class VsphereRunner
    def self.build
      env = ENV
      new(env, DirectorAddress.from_env(env, 'BOSH_VSPHERE_MICROBOSH_IP'))
    end

    def initialize(env, director_address)
      @env              = env
      @bat_helper       = Bosh::Dev::BatHelper.new('vsphere', :dont_care)
      @bosh_cli_session = Bosh::Dev::BoshCliSession.new
      @stemcell_archive = Bosh::Stemcell::Archive.new(bat_helper.bosh_stemcell_path)
      @director_address = director_address
    end

    def run_bats
      prepare_microbosh

      prepare_bat_deployment

      Rake::Task['bat'].invoke
    ensure
      teardown_micro
    end

    private

    attr_reader :env, :bat_helper, :bosh_cli_session, :stemcell_archive, :director_address

    def create_microbosh_manifest
      Dir.chdir(bat_helper.micro_bosh_deployment_dir) do
        Bosh::Dev::VSphere::MicroBoshDeploymentManifest.new.write
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
        Bosh::Dev::VSphere::BatDeploymentManifest.new(director_uuid, stemcell_archive).write
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
        bosh_cli_session.run_bosh "delete stemcell #{stemcell_archive.name} #{stemcell_archive.version}", ignore_failures: true
        bosh_cli_session.run_bosh 'micro delete', ignore_failures: true
      end
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
      else
        nil
      end
    end
  end
end
