require 'spec_helper'
require 'bosh/dev/bat/vsphere_runner'
require 'bosh/dev/bat/director_address'

module Bosh::Dev::Bat
  describe VsphereRunner do
    include FakeFS::SpecHelpers

    describe '.build' do
      it 'returns vsphere runner with injected env and proper director address' do
        bosh_cli_session = instance_double('Bosh::Dev::BoshCliSession')
        Bosh::Dev::BoshCliSession
          .should_receive(:new)
          .and_return(bosh_cli_session)

        director_address = instance_double('Bosh::Dev::Bat::DirectorAddress')
        Bosh::Dev::Bat::DirectorAddress
          .should_receive(:from_env)
          .with(ENV, 'BOSH_VSPHERE_MICROBOSH_IP')
          .and_return(director_address)

        director_uuid = instance_double('Bosh::Dev::Bat::DirectorUuid')
        Bosh::Dev::Bat::DirectorUuid
          .should_receive(:new)
          .with(bosh_cli_session)
          .and_return(director_uuid)

        runner = instance_double('Bosh::Dev::Bat::VsphereRunner')
        described_class
          .should_receive(:new)
          .with(ENV, director_address, director_uuid, bosh_cli_session)
          .and_return(runner)

        expect(described_class.build).to eq(runner)
      end
    end

    let(:stemcell_archive) { instance_double('Bosh::Stemcell::Archive', version: '6', name: 'bosh-infra-hyper-os') }

    let(:bat_helper) do
      instance_double(
        'Bosh::Dev::BatHelper',
        artifacts_dir:              '/VsphereRunner_fake_artifacts_dir',
        micro_bosh_deployment_dir:  '/VsphereRunner_fake_artifacts_dir/fake_micro_bosh_deployment_dir',
        micro_bosh_deployment_name: 'fake_micro_bosh_deployment_name',
        bosh_stemcell_path:         'fake_bosh_stemcell_path',
      )
    end

    let(:microbosh_deployment_manifest) { instance_double('Bosh::Dev::VSphere::MicroBoshDeploymentManifest', write: nil) }
    let(:bat_deployment_manifest) { instance_double('Bosh::Dev::VSphere::BatDeploymentManifest', write: nil) }

    before do
      FileUtils.mkdir_p(bat_helper.micro_bosh_deployment_dir)

      Bosh::Dev::BatHelper.stub(:new).with('vsphere', anything).and_return(bat_helper)
      Bosh::Stemcell::Archive.stub(:new).with(bat_helper.bosh_stemcell_path).and_return(stemcell_archive)

      Bosh::Dev::VSphere::MicroBoshDeploymentManifest.stub(new: microbosh_deployment_manifest)
      Bosh::Dev::VSphere::BatDeploymentManifest.stub(new: bat_deployment_manifest)
    end

    describe '#run_bats' do
      subject { described_class.new(env, director_address, director_uuid, bosh_cli_session) }
      let(:env) { {} }
      let(:director_address) { DirectorAddress.new('director-hostname', 'director-ip') }
      let(:director_uuid) { instance_double('Bosh::Dev::Bat::DirectorUuid') }
      let(:bosh_cli_session) { instance_double('Bosh::Dev::BoshCliSession', run_bosh: 'fake_BoshCliSession_output') }

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
        bosh_cli_session.should_receive(:run_bosh).with('upload stemcell fake_bosh_stemcell_path', debug_on_fail: true)
        subject.run_bats
      end

      it 'generates a bat manifest' do
        bat_deployment_manifest.should_receive(:write) do
          FileUtils.touch(File.join(Dir.pwd, 'FAKE_BAT_MANIFEST'))
        end

        Bosh::Dev::VSphere::BatDeploymentManifest.should_receive(:new).
          with(env, director_uuid, stemcell_archive).and_return(bat_deployment_manifest)

        subject.run_bats

        expect(Dir.entries(bat_helper.artifacts_dir)).to include('FAKE_BAT_MANIFEST')
      end

      it 'sets the the required environment variables' do
        expect(env['BAT_DEPLOYMENT_SPEC']).to be_nil
        expect(env['BAT_DIRECTOR']).to be_nil
        expect(env['BAT_DNS_HOST']).to be_nil
        expect(env['BAT_STEMCELL']).to be_nil
        expect(env['BAT_VCAP_PASSWORD']).to be_nil
        expect(env['BAT_FAST']).to be_nil

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
        bosh_cli_session.should_receive(:run_bosh).with("delete stemcell #{stemcell_archive.name} #{stemcell_archive.version}", ignore_failures: true)
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
          bosh_cli_session.should_receive(:run_bosh).with("delete stemcell #{stemcell_archive.name} #{stemcell_archive.version}", ignore_failures: true)
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
