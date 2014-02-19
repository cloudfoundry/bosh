require 'json'
require 'spec_helper'
require 'cli/client/compiled_packages_client'

describe Bosh::Cli::Client::CompiledPackagesClient do
  subject(:client) { described_class.new(director) }
  let(:director) { instance_double('Bosh::Cli::Client::Director') }

  describe '#export' do
    it 'downloads and writes the compiled packages export' do
      expected_path = '/compiled_package_groups/export'

      expected_json_params = JSON.dump(
        stemcell_name:    'stemcell-name',
        stemcell_version: 'stemcell-version',
        release_name:     'release-name',
        release_version:  'release-version',
      )

      expect(director).to receive(:post)
        .with(expected_path, 'application/json', expected_json_params, {}, file: true)
        .and_return([200, '/downloaded-file-path', {}])

      expect(client.export('release-name', 'release-version', 'stemcell-name', 'stemcell-version')).to eq('/downloaded-file-path')
    end
  end

  describe '#import' do
    it 'delegates to the cli director to post the file' do
      director.stub(:upload_and_track)
      client.import('/exported/compiled/packages.tgz')

      expect(director).to have_received(:upload_and_track).with(
        :post,
        '/compiled_package_groups/import',
        '/exported/compiled/packages.tgz',
        { content_type: 'application/x-compressed' },
      )
    end
  end
end
