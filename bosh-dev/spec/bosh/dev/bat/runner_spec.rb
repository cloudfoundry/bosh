require 'spec_helper'
require 'bosh/dev/bat/runner'
require 'bosh/dev/bat_helper'
require 'bosh/dev/bat/director_address'
require 'bosh/dev/bat/director_uuid'
require 'bosh/dev/bosh_cli_session'
require 'bosh/stemcell/archive'

module Bosh::Dev::Bat
  describe Runner do
    include FakeFS::SpecHelpers

    describe '#run_bats' do
      subject do
        described_class.new(
          env,
          bat_helper,
          director_address,
          bosh_cli_session,
          stemcell_archive,
          microbosh_deployment_manifest,
          bat_deployment_manifest
        )
      end

      let(:env) do
        { 'BOSH_VPC_SUBDOMAIN'            => 'fake_BOSH_VPC_SUBDOMAIN',
          'BOSH_JENKINS_DEPLOYMENTS_REPO' => 'fake_BOSH_JENKINS_DEPLOYMENTS_REPO',
        }
      end

      let(:bat_helper) do
        instance_double(
          'Bosh::Dev::BatHelper',
          artifacts_dir:              '/AwsRunner_fake_artifacts_dir',
          micro_bosh_deployment_dir:  '/AwsRunner_fake_artifacts_dir/fake_micro_bosh_deployment_dir',
          micro_bosh_deployment_name: 'fake_micro_bosh_deployment_name',
          bosh_stemcell_path:         'fake_bosh_stemcell_path',
        )
      end

      let(:director_address) { DirectorAddress.new('director-hostname', 'director-ip') }
      let(:bosh_cli_session) { instance_double('Bosh::Dev::BoshCliSession', run_bosh: 'fake_BoshCliSession_output') }
      let(:stemcell_archive) { instance_double('Bosh::Stemcell::Archive', version: '6') }

      let(:microbosh_deployment_manifest) { double('microbosh-deployment-manifest', write: nil) }
      let(:bat_deployment_manifest) { double('bat-deployment-manifest', write: nil) }

      before do
        FileUtils.mkdir('/mnt')
        FileUtils.mkdir_p(bat_helper.micro_bosh_deployment_dir)
      end

      before { Rake::Task.stub(:[]).with('bat').and_return(bat_rake_task) }
      let(:bat_rake_task) { double("Rake::Task['bat']", invoke: nil) }

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
        bosh_cli_session.should_receive(:run_bosh).with('micro deploy fake_bosh_stemcell_path')
        subject.run_bats
      end

      it 'logs in to the micro' do
        bosh_cli_session.should_receive(:run_bosh).with('login admin admin')
        subject.run_bats
      end

      it 'uploads the bosh stemcell to the micro' do
        bosh_cli_session.should_receive(:run_bosh).with(
          'upload stemcell fake_bosh_stemcell_path', debug_on_fail: true)
        subject.run_bats
      end

      it 'generates a bat manifest' do
        bat_deployment_manifest.should_receive(:write) do
          FileUtils.touch(File.join(Dir.pwd, 'FAKE_BAT_MANIFEST'))
        end

        subject.run_bats

        expect(Dir.entries(bat_helper.artifacts_dir)).to include('FAKE_BAT_MANIFEST')
      end

      it 'sets the the required environment variables' do
        subject.run_bats
        expect(env['BAT_DEPLOYMENT_SPEC']).to eq(File.join(bat_helper.artifacts_dir, 'bat.yml'))
        expect(env['BAT_DIRECTOR']).to eq('director-hostname')
        expect(env['BAT_DNS_HOST']).to eq('director-ip')
        expect(env['BAT_STEMCELL']).to eq(bat_helper.bosh_stemcell_path)
        expect(env['BAT_VCAP_PASSWORD']).to eq('c1oudc0w')
        expect(env['BAT_FAST']).to eq('true')
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
        bosh_cli_session.should_receive(:run_bosh).with(
          "delete stemcell bosh-stemcell #{stemcell_archive.version}", ignore_failures: true)
        subject.run_bats
      end

      it 'deletes the micro' do
        bosh_cli_session.should_receive(:run_bosh).with('micro delete', ignore_failures: true)
        subject.run_bats
      end

      context 'when a failure occurs' do
        before { bat_rake_task.should_receive(:invoke).and_raise }

        it 'deletes the bat deployment' do
          bosh_cli_session.should_receive(:run_bosh).with(
            'delete deployment bat', ignore_failures: true)
          expect { subject.run_bats }.to raise_error
        end

        it 'deletes the stemcell' do
          bosh_cli_session.should_receive(:run_bosh).with(
            "delete stemcell bosh-stemcell #{stemcell_archive.version}", ignore_failures: true)
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
