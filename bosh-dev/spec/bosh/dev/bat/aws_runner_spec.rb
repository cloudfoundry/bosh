require 'spec_helper'
require 'bosh/dev/bat/aws_runner'

module Bosh::Dev::Bat
  describe AwsRunner do
    include FakeFS::SpecHelpers

    let(:bosh_cli_session) { instance_double('Bosh::Dev::BoshCliSession', run_bosh: 'fake_BoshCliSession_output') }
    let(:stemcell_archive) { instance_double('Bosh::Dev::Bat::StemcellArchive', version: '6') }

    let(:bat_helper) do
      instance_double('Bosh::Dev::BatHelper',
                      artifacts_dir: '/AwsRunner_fake_artifacts_dir',
                      micro_bosh_deployment_dir: '/AwsRunner_fake_artifacts_dir/fake_micro_bosh_deployment_dir',
                      micro_bosh_deployment_name: 'fake_micro_bosh_deployment_name',
                      micro_bosh_stemcell_path: 'fake_micro_bosh_stemcell_path',
                      bosh_stemcell_path: 'fake_bosh_stemcell_path')
    end

    let(:microbosh_deployment_manifest) { instance_double('Bosh::Dev::Aws::MicroBoshDeploymentManifest', write: nil) }
    let(:bat_deployment_manifest) { instance_double('Bosh::Dev::Aws::BatDeploymentManifest', write: nil) }

    before do
      FileUtils.mkdir('/mnt')
      FileUtils.mkdir_p(bat_helper.micro_bosh_deployment_dir)

      Bosh::Dev::BatHelper.stub(:new).with('aws').and_return(bat_helper)
      Bosh::Dev::BoshCliSession.stub(new: bosh_cli_session)
      StemcellArchive.stub(:new).with(bat_helper.bosh_stemcell_path).and_return(stemcell_archive)

      Bosh::Dev::Aws::MicroBoshDeploymentManifest.stub(new: microbosh_deployment_manifest)
      Bosh::Dev::Aws::BatDeploymentManifest.stub(new: bat_deployment_manifest)

      ENV.stub(:to_hash).and_return(
        'BOSH_VPC_SUBDOMAIN' => 'fake_BOSH_VPC_SUBDOMAIN',
        'BOSH_JENKINS_DEPLOYMENTS_REPO' => 'fake_BOSH_JENKINS_DEPLOYMENTS_REPO',
      )
    end

    around do |example|
      original_env = ENV

      begin
        ENV.clear
        example.run
      ensure
        ENV.update(original_env)
      end
    end

    describe '#run_bats' do
      let(:director_hostname) { 'micro.fake_BOSH_VPC_SUBDOMAIN.cf-app.com' }
      let(:director_ip) { 'micro.fake_BOSH_VPC_SUBDOMAIN.cf-app.com' }
      let(:bat_rake_task) { double("Rake::Task['bat']", invoke: nil) }

      before do
        Rake::Task.stub(:[]).with('bat').and_return(bat_rake_task)
        Resolv.stub(:getaddress).with(director_hostname).and_return(director_ip)
      end

      it 'generates a micro manifest' do
        microbosh_deployment_manifest.should_receive(:write) do
          FileUtils.touch(File.join(Dir.pwd, 'FAKE_MICROBOSH_MANIFEST'))
        end

        subject.run_bats

        expect(Dir.entries(bat_helper.micro_bosh_deployment_dir)).to include('FAKE_MICROBOSH_MANIFEST')
      end

      it 'targets the micro' do
        bosh_cli_session.should_receive(:run_bosh).with('micro deployment fake_micro_bosh_deployment_name')
        subject.run_bats
      end

      it 'deploys the micro' do
        bosh_cli_session.should_receive(:run_bosh).with('micro deploy fake_micro_bosh_stemcell_path')
        subject.run_bats
      end

      it 'logs in to the micro' do
        bosh_cli_session.should_receive(:run_bosh).with('login admin admin')
        subject.run_bats
      end

      it 'uploads the bosh stemcell to the micro' do
        bosh_cli_session.should_receive(:run_bosh).with('upload stemcell fake_bosh_stemcell_path', debug_on_fail: true)
        subject.run_bats
      end

      it 'generates a bat manifest' do
        bat_deployment_manifest.should_receive(:write) do
          FileUtils.touch(File.join(Dir.pwd, 'FAKE_BAT_MANIFEST'))
        end

        Bosh::Dev::Aws::BatDeploymentManifest.should_receive(:new).
          with(bosh_cli_session, stemcell_archive.version).and_return(bat_deployment_manifest)

        subject.run_bats

        expect(Dir.entries(bat_helper.artifacts_dir)).to include('FAKE_BAT_MANIFEST')
      end

      it 'sets the the required environment variables' do
        expect(ENV['BAT_DEPLOYMENT_SPEC']).to be_nil
        expect(ENV['BAT_DIRECTOR']).to be_nil
        expect(ENV['BAT_DNS_HOST']).to be_nil
        expect(ENV['BAT_STEMCELL']).to be_nil
        expect(ENV['BAT_VCAP_PASSWORD']).to be_nil
        expect(ENV['BAT_FAST']).to be_nil

        subject.run_bats

        expect(ENV['BAT_DEPLOYMENT_SPEC']).to eq(File.join(bat_helper.artifacts_dir, 'bat.yml'))
        expect(ENV['BAT_DIRECTOR']).to eq(director_hostname)
        expect(ENV['BAT_DNS_HOST']).to eq(director_ip)
        expect(ENV['BAT_STEMCELL']).to eq(bat_helper.bosh_stemcell_path)
        expect(ENV['BAT_VCAP_PASSWORD']).to eq('c1oudc0w')
        expect(ENV['BAT_FAST']).to eq('true')
      end

      it 'invokes the "bat" rake task' do
        bat_rake_task.should_receive(:invoke)
        subject.run_bats
      end

      it 'deletes the bat deployment' do
        bosh_cli_session.should_receive(:run_bosh).with('delete deployment bat', ignore_failures: true)
        subject.run_bats
      end

      it 'deletes the stemcell' do
        bosh_cli_session.should_receive(:run_bosh).with("delete stemcell bosh-stemcell #{stemcell_archive.version}", ignore_failures: true)
        subject.run_bats
      end

      it 'deletes the micro' do
        bosh_cli_session.should_receive(:run_bosh).with('micro delete', ignore_failures: true)
        subject.run_bats
      end

      context 'when a failure occurs' do
        before do
          bat_rake_task.should_receive(:invoke).and_raise
        end

        it 'deletes the bat deployment' do
          bosh_cli_session.should_receive(:run_bosh).with('delete deployment bat', ignore_failures: true)
          expect { subject.run_bats }.to raise_error
        end

        it 'deletes the stemcell' do
          bosh_cli_session.should_receive(:run_bosh).with("delete stemcell bosh-stemcell #{stemcell_archive.version}", ignore_failures: true)
          expect { subject.run_bats }.to raise_error
        end

        it 'deletes the micro' do
          bosh_cli_session.should_receive(:run_bosh).with('micro delete', ignore_failures: true)
          expect { subject.run_bats }.to raise_error
        end
      end
    end
  end
end
