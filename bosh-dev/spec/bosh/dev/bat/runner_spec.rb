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

    subject do
      described_class.new(
        env,
        bat_helper,
        director_address,
        bosh_cli_session,
        stemcell_archive,
        microbosh_deployment_manifest,
        bat_deployment_manifest,
        microbosh_deployment_cleaner,
      )
    end

    let(:env) { {} }

    before { FileUtils.mkdir_p(bat_helper.micro_bosh_deployment_dir) }
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
    let(:bat_deployment_manifest) { double('bat-deployment-manifest', write: nil) }

    describe '#deploy_microbosh_and_run_bats' do
      before { subject.stub(:run_bats) }

      it 'generates a micro manifest' do
        microbosh_deployment_manifest.should_receive(:write) do
          FileUtils.touch(File.join(Dir.pwd, 'FAKE_MICROBOSH_MANIFEST'))
        end
        subject.deploy_microbosh_and_run_bats
        expect(Dir.entries(bat_helper.micro_bosh_deployment_dir)).to include('FAKE_MICROBOSH_MANIFEST')
      end

      it 'cleans any previous deployments out' do
        microbosh_deployment_cleaner.should_receive(:clean)
        subject.deploy_microbosh_and_run_bats
      end

      it 'targets the micro' do
        bosh_cli_session.should_receive(:run_bosh).with(
          'micro deployment fake_micro_bosh_deployment_name')
        subject.deploy_microbosh_and_run_bats
      end

      it 'deploys the micro' do
        bosh_cli_session.should_receive(:run_bosh).with(
          'micro deploy fake_bosh_stemcell_path')
        subject.deploy_microbosh_and_run_bats
      end

      it 'logs in to the micro' do
        bosh_cli_session.should_receive(:run_bosh).with('login admin admin')
        subject.deploy_microbosh_and_run_bats
      end

      it 'uploads the bosh stemcell to the micro' do
        bosh_cli_session.should_receive(:run_bosh).with(
          'upload stemcell fake_bosh_stemcell_path', debug_on_fail: true)
        subject.deploy_microbosh_and_run_bats
      end

      it 'runs bats' do
        subject.should_receive(:run_bats)
        subject.deploy_microbosh_and_run_bats
      end
    end

    describe '#run_bats' do
      before { Rake::Task.stub(:[]).with('bat').and_return(bat_rake_task) }
      let(:bat_rake_task) { double("Rake::Task['bat']", invoke: nil) }

      describe 'targetting the micro' do
        shared_examples_for 'a method that targets the micro correctly' do
          it 'targets the micro with the correct username and password' do
            expect(bosh_cli_session).to receive(:run_bosh).with(
                                          "-u #{expected_username} -p #{expected_password} target director-hostname"
                                        )

            subject.run_bats
          end
        end

        context 'when the environment does not specify a username or password' do
          let(:expected_username) { 'admin' }
          let(:expected_password) { 'admin' }

          include_examples 'a method that targets the micro correctly'
        end

        context 'when the environment specifies a username' do
          let(:expected_username) { 'username' }
          let(:expected_password) { 'admin' }

          before do
            env['BOSH_USER'] = 'username'
          end

          include_examples 'a method that targets the micro correctly'
        end

        context 'when the environment specifies a password' do
          let(:expected_username) { 'admin' }
          let(:expected_password) { 'password' }

          before do
            env['BOSH_PASSWORD'] = 'password'
          end

          include_examples 'a method that targets the micro correctly'
        end

        context 'when the environment specifies both a password and password' do
          let(:expected_username) { 'username' }
          let(:expected_password) { 'password' }

          before do
            env['BOSH_USER'] = 'username'
            env['BOSH_PASSWORD'] = 'password'
          end

          include_examples 'a method that targets the micro correctly'
        end

        it 'targets the director before writing the bosh manifest' do
          expect(bosh_cli_session).to receive(:run_bosh).with(/target director-hostname/).ordered
          expect(bat_deployment_manifest).to receive(:write).with(no_args).ordered

          subject.run_bats
        end
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
        expect(env['BAT_INFRASTRUCTURE']).to eq('infrastructure')
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
        bat_rake_task.should_receive(:invoke)
        subject.run_bats
      end
    end
  end
end
