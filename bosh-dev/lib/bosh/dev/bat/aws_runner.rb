require 'bosh/dev/bat'
require 'bosh/dev/bat_helper'
require 'bosh/dev/bat/bosh_cli_session'
require 'bosh/dev/bat/shell'
require 'bosh/dev/bat/stemcell_archive'
require 'bosh/dev/aws/micro_bosh_deployment_manifest'
require 'bosh/dev/aws/bat_deployment_manifest'

module Bosh::Dev::Bat
  class AwsRunner
    include Rake::FileUtilsExt

    def initialize
      @bat_helper = Bosh::Dev::BatHelper.new('aws')
      @shell = Shell.new
      @bosh_cli_session = BoshCliSession.new
      @stemcell_archive = StemcellArchive.new(bat_helper.bosh_stemcell_path)
    end

    def deploy_micro
      get_deployments_aws

      Dir.chdir(bat_helper.artifacts_dir) do
        Dir.chdir(bat_helper.micro_bosh_deployment_dir) do
          micro_deployment_manifest = Bosh::Dev::Aws::MicroBoshDeploymentManifest.new(bosh_cli_session)
          micro_deployment_manifest.write
        end
        bosh_cli_session.run_bosh "micro deployment #{bat_helper.micro_bosh_deployment_name}"
        bosh_cli_session.run_bosh "micro deploy #{bat_helper.micro_bosh_stemcell_path}"
        bosh_cli_session.run_bosh 'login admin admin'

        bosh_cli_session.run_bosh "upload stemcell #{bat_helper.bosh_stemcell_path}", debug_on_fail: true

        bat_deployment_manifest = Bosh::Dev::Aws::BatDeploymentManifest.new(bosh_cli_session, stemcell_archive)
        bat_deployment_manifest.write
      end
    end

    def run_bats
      director = "micro.#{ENV['BOSH_VPC_SUBDOMAIN']}.cf-app.com"

      ENV['BAT_DIRECTOR'] = director
      ENV['BAT_STEMCELL'] = bat_helper.bosh_stemcell_path
      ENV['BAT_DEPLOYMENT_SPEC'] = File.join(bat_helper.artifacts_dir, 'bat.yml')
      ENV['BAT_VCAP_PASSWORD'] = 'c1oudc0w'
      ENV['BAT_FAST'] = 'true'
      ENV['BAT_DNS_HOST'] = Resolv.getaddress(director)

      Rake::Task['bat'].invoke
    end

    def teardown_micro
      Dir.chdir(bat_helper.artifacts_dir) do
        bosh_cli_session.run_bosh 'delete deployment bat', ignore_failures: true
        bosh_cli_session.run_bosh 'micro delete', ignore_failures: true
      end
    end

    private

    attr_reader :bat_helper, :bosh_cli_session, :shell, :stemcell_archive

    def get_deployments_aws
      mnt = ENV.fetch('FAKE_MNT', '/mnt')
      Dir.chdir(mnt) do
        if Dir.exists?('deployments')
          Dir.chdir('deployments') do
            shell.run('git pull')
          end
        else
          shell.run("git clone #{ENV.to_hash.fetch('BOSH_JENKINS_DEPLOYMENTS_REPO')} deployments")
        end
      end
    end
  end
end
