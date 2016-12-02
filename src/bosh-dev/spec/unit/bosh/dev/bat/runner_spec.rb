require 'spec_helper'
require 'bosh/dev/bat/runner'
require 'bosh/dev/bat/artifacts'
require 'bosh/dev/bat/director_address'
require 'bosh/dev/bat/director_uuid'
require 'bosh/dev/bosh_cli_session'
require 'bosh/stemcell/archive'

module Bosh::Dev::Bat
  describe Runner do
    include FakeFS::SpecHelpers

    subject do
      described_class.new(
        env,
        artifacts,
        director_address,
        bosh_cli_session,
        stemcell_archive,
        microbosh_deployment_manifest,
        bat_deployment_manifest,
        microbosh_deployment_cleaner,
        logger,
      )
    end

    let(:env) { {} }

    before { FileUtils.mkdir_p(artifacts.micro_bosh_deployment_dir) }
    let(:artifacts) do
      instance_double(
        'Bosh::Dev::Bat::Artifacts',
        path:                       '/AwsRunner_fake_artifacts_path',
        micro_bosh_deployment_dir:  '/AwsRunner_fake_artifacts_path/fake_micro_bosh_deployment_dir',
        micro_bosh_deployment_name: 'fake_micro_bosh_deployment_name',
        stemcell_path:              'fake_bosh_stemcell_path',
      )
    end

    let(:director_address) { DirectorAddress.new('director-hostname', 'director-ip') }
    let(:bosh_cli_session) { instance_double('Bosh::Dev::BoshCliSession', run_bosh: 'fake_BoshCliSession_output') }
    let(:stemcell_archive) do
      instance_double(
        'Bosh::Stemcell::Archive',
        name: 'stemcell-name',
        version: '6',
        infrastructure: 'infrastructure',
      )
    end

    # Multiple implementations for the following
    let(:microbosh_deployment_manifest) { double('microbosh-deployment-manifest', write: nil) }
    let(:microbosh_deployment_cleaner) { double('microbosh-deployment-cleaner', clean: nil) }
    let(:bat_deployment_manifest) { double('bat-deployment-manifest', net_type: 'net-type', write: nil) }

    describe '#deploy_bats_microbosh' do
      before { allow(subject).to receive(:run_bats) }

      it 'generates a micro manifest' do
        expect(microbosh_deployment_manifest).to receive(:write) do
          FileUtils.touch(File.join(Dir.pwd, 'FAKE_MICROBOSH_MANIFEST'))
        end
        subject.deploy_bats_microbosh
        expect(Dir.entries(artifacts.micro_bosh_deployment_dir)).to include('FAKE_MICROBOSH_MANIFEST')
      end

      it 'cleans any previous deployments out' do
        expect(microbosh_deployment_cleaner).to receive(:clean)
        subject.deploy_bats_microbosh
      end

      it 'targets the micro' do
        expect(bosh_cli_session).to receive(:run_bosh).with(
          'micro deployment fake_micro_bosh_deployment_name')
        subject.deploy_bats_microbosh
      end

      it 'deploys the micro' do
        expect(bosh_cli_session).to receive(:run_bosh).with(
          'micro deploy fake_bosh_stemcell_path')
        subject.deploy_bats_microbosh
      end

      it 'logs in to the micro' do
        expect(bosh_cli_session).to receive(:run_bosh).with('login admin admin')
        subject.deploy_bats_microbosh
      end
    end

    describe '#run_bats' do
      before { allow(Rake::Task).to receive(:[]).with('bat').and_return(bat_rake_task) }
      let(:bat_rake_task) { double("Rake::Task['bat']", invoke: nil) }

      describe 'targetting the micro' do
        def self.it_targets_micro(username, password)
          it 'targets the micro with the correct username and password' do
            expect(bosh_cli_session).to receive(:run_bosh).with(
              "-u #{username} -p #{password} target director-hostname"
            )
            subject.run_bats
          end
        end

        context 'when the environment does not specify a username or password' do
          it_targets_micro 'admin', 'admin'
        end

        context 'when the environment specifies a username' do
          before { env['BOSH_USER'] = 'username' }
          it_targets_micro 'username', 'admin'
        end

        context 'when the environment specifies a password' do
          before { env['BOSH_PASSWORD'] = 'password' }
          it_targets_micro 'admin', 'password'
        end

        context 'when the environment specifies both a password and password' do
          before do
            env['BOSH_USER'] = 'username'
            env['BOSH_PASSWORD'] = 'password'
          end
          it_targets_micro 'username', 'password'
        end

        it 'targets the director before writing the bosh manifest' do
          expect(bosh_cli_session).to receive(:run_bosh).with(/target director-hostname/).ordered
          expect(bat_deployment_manifest).to receive(:write).with(no_args).ordered
          subject.run_bats
        end
      end

      it 'generates a bat manifest' do
        expect(bat_deployment_manifest).to receive(:write) do
          FileUtils.touch(File.join(Dir.pwd, 'FAKE_BAT_MANIFEST'))
        end
        subject.run_bats
        expect(Dir.entries(artifacts.path)).to include('FAKE_BAT_MANIFEST')
      end

      it 'sets the the required environment variables' do
        subject.run_bats
        expect(env['BAT_DEPLOYMENT_SPEC']).to eq(File.join(artifacts.path, 'bat.yml'))
        expect(env['BAT_DIRECTOR']).to eq('director-hostname')
        expect(env['BAT_DNS_HOST']).to eq('director-ip')
        expect(env['BAT_STEMCELL']).to eq(artifacts.stemcell_path)
        expect(env['BAT_VCAP_PASSWORD']).to eq('c1oudc0w')
        expect(env['BAT_INFRASTRUCTURE']).to eq('infrastructure')
        expect(env['BAT_NETWORKING']).to eq('net-type')
      end

      it 'sets BAT_VCAP_PRIVATE_KEY to BOSH_OPENSTACK_PRIVATE_KEY if present' do
        env['BOSH_OPENSTACK_PRIVATE_KEY'] = 'private-key-path'
        subject.run_bats
        expect(env['BAT_VCAP_PRIVATE_KEY']).to eq('private-key-path')
      end

      it 'sets BAT_VCAP_PRIVATE_KEY to BOSH_KEY_PATH if present' do
        env['BOSH_KEY_PATH'] = 'private-key-path'
        subject.run_bats
        expect(env['BAT_VCAP_PRIVATE_KEY']).to eq('private-key-path')
      end

      it 'invokes the "bat" rake task' do
        expect(bat_rake_task).to receive(:invoke)
        subject.run_bats
      end
    end
  end
end
