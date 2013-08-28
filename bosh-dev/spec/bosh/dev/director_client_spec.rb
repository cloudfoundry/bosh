require 'spec_helper'

require 'cli/director'
require 'bosh/dev/director_client'

module Bosh::Dev
  describe DirectorClient do
    let (:director_handle) { instance_double('Bosh::Cli::Director') }
    let(:cli) { instance_double('Bosh::Dev::BoshCliSession', run_bosh: nil) }

    let (:valid_stemcell_list_1) do
      [
        { 'name' => 'fake-stemcell', 'version' => '007', 'cid' => 'ami-amazon_guid_1' },
        { 'name' => 'fake-stemcell', 'version' => '222', 'cid' => 'ami-amazon_guid_2' }
      ]
    end

    let (:valid_stemcell_list_2) do
      [
        { 'name' => 'fake-stemcell', 'version' => '007', 'cid' => 'ami-amazon_guid_1' },
        { 'name' => 'fake-stemcell', 'version' => '222', 'cid' => 'ami-amazon_guid_2' }
      ]
    end

    subject(:director_client) do
      DirectorClient.new(
        uri: 'bosh.example.com',
        username: 'fake_username',
        password: 'fake_password',
      )
    end

    before do
      BoshCliSession.stub(new: cli)

      director_klass = class_double('Bosh::Cli::Director').as_stubbed_const
      director_klass.stub(:new).with(
        'bosh.example.com',
        'fake_username',
        'fake_password',
      ).and_return(director_handle)
    end

    describe '#stemcells' do
      it 'lists stemcells stored on director without shelling out' do
        director_handle.stub(:list_stemcells) { valid_stemcell_list_1 }
        expect(director_client.stemcells).to eq valid_stemcell_list_2
      end
    end

    describe '#has_stemcell?' do
      before do
        director_handle.stub(:list_stemcells) { valid_stemcell_list_1 }
      end

      it 'local stemcell exists on director' do
        expect(director_client.has_stemcell?('fake-stemcell', '007')).to be_true
      end

      it 'local stemcell does not exists on director' do
        expect(director_client.has_stemcell?('non-such-stemcell', '-1')).to be_false
      end
    end

    describe '#upload_stemcell' do
      let(:stemcell_archive) do
        instance_double('Bosh::Stemcell::Archive', name: 'fake-stemcell', version: '008', path: '/path/to/fake-stemcell-008.tgz')
      end

      before do
        director_handle.stub(:list_stemcells) { [] }
      end

      it 'targets its director with the cli' do
        cli.should_receive(:run_bosh).with('target bosh.example.com')

        director_client.upload_stemcell(stemcell_archive)
      end

      it 'logs in to the director with the cli' do
        cli.should_receive(:run_bosh).with('login fake_username fake_password')

        director_client.upload_stemcell(stemcell_archive)
      end

      it 'uploads the stemcell with the cli' do
        cli.should_receive(:run_bosh).with('upload stemcell /path/to/fake-stemcell-008.tgz', debug_on_fail: true)

        director_client.upload_stemcell(stemcell_archive)
      end

      context 'when the stemcell being uploaded exists on the director' do
        before do
          director_handle.stub(:list_stemcells).and_return([{ 'name' => 'fake-stemcell', 'version' => '008' }])
        end

        it 'does not re-upload it' do
          cli.should_not_receive(:run_bosh).with(/upload stemcell/, debug_on_fail: true)

          director_client.upload_stemcell(stemcell_archive)
        end
      end
    end

    describe '#upload_release' do
      it 'uploads the release using the cli, rebasing assuming this is a dev release' do
        cli.should_receive(:run_bosh).with('upload release /path/to/fake-release.tgz --rebase', debug_on_fail: true)

        director_client.upload_release('/path/to/fake-release.tgz')
      end
    end

    describe 'deploy' do
      it 'sets the deployment and then runs a deplpy using the cli' do
        cli.should_receive(:run_bosh).with('deployment /path/to/fake-manifest.yml').ordered
        cli.should_receive(:run_bosh).with('deploy', debug_on_fail: true).ordered

        director_client.deploy('/path/to/fake-manifest.yml')
      end
    end
  end
end
