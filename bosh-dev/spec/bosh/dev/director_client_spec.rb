require 'spec_helper'
require 'bosh/dev/director_client'
require 'bosh/stemcell/archive'

module Bosh::Dev
  describe DirectorClient do
    subject(:director_client) do
      DirectorClient.new(
        'bosh.example.com',
        'fake_username',
        'fake_password',
        bosh_cli_session,
      )
    end

    let(:bosh_cli_session) { instance_double('Bosh::Dev::BoshCliSession', run_bosh: nil) }

    before do
      class_double('Bosh::Cli::Client::Director')
        .as_stubbed_const
        .stub(:new)
        .with('bosh.example.com', 'fake_username', 'fake_password')
        .and_return(director_handle)
    end

    let(:director_handle) { instance_double('Bosh::Cli::Client::Director') }

    describe '#upload_stemcell' do
      let(:stemcell_archive) do
        instance_double('Bosh::Stemcell::Archive', {
          name: 'fake-stemcell',
          version: '008',
          path: '/path/to/fake-stemcell-008.tgz',
        })
      end

      before { director_handle.stub(:list_stemcells) { [] } }

      it 'uploads the stemcell with the cli' do
        bosh_cli_session.should_receive(:run_bosh).
          with('upload stemcell /path/to/fake-stemcell-008.tgz', debug_on_fail: true)
        director_client.upload_stemcell(stemcell_archive)
      end

      it 'always re-targets and logs in first' do
        target_retryable = double('target-retryable')
        Bosh::Retryable.stub(:new).with(tries: 3, on: [RuntimeError]).and_return(target_retryable)

        bosh_cli_session.should_receive(:run_bosh).with('target bosh.example.com', retryable: target_retryable).ordered
        bosh_cli_session.should_receive(:run_bosh).with('login fake_username fake_password').ordered
        bosh_cli_session.should_receive(:run_bosh).with(/upload stemcell/, debug_on_fail: true).ordered

        director_client.upload_stemcell(stemcell_archive)
      end

      context 'when the stemcell being uploaded exists on the director' do
        before { director_handle.stub(:list_stemcells).and_return([{ 'name' => 'fake-stemcell', 'version' => '008' }]) }

        it 'does not re-upload it' do
          bosh_cli_session.should_not_receive(:run_bosh).with(/upload stemcell/, debug_on_fail: true)
          director_client.upload_stemcell(stemcell_archive)
        end
      end
    end

    describe '#upload_release' do
      it 'uploads the release using the cli, skipping if the release already exists' do
        bosh_cli_session.should_receive(:run_bosh).
          with('upload release /path/to/fake-release.tgz --skip-if-exists', debug_on_fail: true)
        director_client.upload_release('/path/to/fake-release.tgz')
      end

      it 'always re-targets and logs in first' do
        target_retryable = double('target-retryable')
        Bosh::Retryable.stub(:new).with(tries: 3, on: [RuntimeError]).and_return(target_retryable)

        bosh_cli_session.should_receive(:run_bosh).with('target bosh.example.com', retryable: target_retryable).ordered
        bosh_cli_session.should_receive(:run_bosh).with('login fake_username fake_password').ordered
        bosh_cli_session.should_receive(:run_bosh).with(/upload release/, debug_on_fail: true).ordered

        director_client.upload_release('/path/to/fake-release.tgz')
      end
    end

    describe '#deploy' do
      let(:manifest_path) { '/path/to/fake-manifest.yml' }
      include FakeFS::SpecHelpers

      let(:manifest_yaml) { "---\n{}" }

      before do
        FileUtils.mkdir_p(File.dirname(manifest_path))
        File.open(manifest_path, 'w') { |f| f.write manifest_yaml }
        allow(director_handle).to receive(:uuid)
      end

      context 'when directors uuid has changed' do
        it 'updates the uuid in the manifest to the one from the targetted director' do
          allow(director_handle).to receive('uuid').and_return('uuid_value')

          director_client.deploy(manifest_path)
          manifest = YAML.load_file(manifest_path)
          expect(manifest['director_uuid']).to eq('uuid_value')
        end
      end

      context 'when directors uuid has not changed' do
        let(:manifest_yaml) do
<<EOF
---
director_uuid: uuid_value
test_ref: &ref
  test_member: true
test_pointer: *ref
EOF
        end

        it 'does not change the manifest contents (i.e. update references and check into git)' do
          allow(director_handle).to receive(:uuid).and_return('uuid_value')

          director_client.deploy(manifest_path)
          manifest = File.read(manifest_path)
          expect(manifest).to eq(manifest_yaml)
        end
      end

      it 'sets the deployment and then runs a deploy using the cli' do
        bosh_cli_session.should_receive(:run_bosh).with('deployment /path/to/fake-manifest.yml').ordered
        bosh_cli_session.should_receive(:run_bosh).with('deploy', debug_on_fail: true).ordered

        director_client.deploy(manifest_path)
      end

      it 'always re-targets and logs in first' do
        target_retryable = double('target-retryable')
        Bosh::Retryable.stub(:new).with(tries: 3, on: [RuntimeError]).and_return(target_retryable)

        bosh_cli_session.should_receive(:run_bosh).with('target bosh.example.com', retryable: target_retryable).ordered
        bosh_cli_session.should_receive(:run_bosh).with('login fake_username fake_password').ordered
        bosh_cli_session.should_receive(:run_bosh).with(/deployment/).ordered
        bosh_cli_session.should_receive(:run_bosh).with(/deploy/, debug_on_fail: true).ordered

        director_client.deploy(manifest_path)
      end
    end

    describe '#clean_up' do
      it 'cleans up resources on the director' do
        bosh_cli_session.should_receive(:run_bosh).with('cleanup', debug_on_fail: true)
        director_client.clean_up
      end

      it 'always re-targets and logs in first' do
        target_retryable = double('target-retryable')
        Bosh::Retryable.stub(:new).with(tries: 3, on: [RuntimeError]).and_return(target_retryable)

        bosh_cli_session.should_receive(:run_bosh).with('target bosh.example.com', retryable: target_retryable).ordered
        bosh_cli_session.should_receive(:run_bosh).with('login fake_username fake_password').ordered
        bosh_cli_session.should_receive(:run_bosh).with(/cleanup/, debug_on_fail: true).ordered

        director_client.clean_up
      end
    end
  end
end
