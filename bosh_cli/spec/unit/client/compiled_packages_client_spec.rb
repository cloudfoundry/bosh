require 'spec_helper'
require 'cli/client/compiled_packages_client'

describe  Bosh::Cli::Client::CompiledPackagesClient do
  subject(:client) { described_class.new(director)}
  let(:director) { instance_double('Bosh::Cli::Client::Director') }

  describe '#export' do
    it 'downloads and writes the compiled packages export' do
      expected_path = '/stemcells/stemcell-name/stemcell-version/releases/release-name/release-version/compiled_packages'

      expect(director).to receive(:get)
        .with(expected_path, nil, nil, {}, file: true)
        .and_return([200, '/downloaded-file-path', {}])

      expect(client.export('release-name', 'release-version', 'stemcell-name', 'stemcell-version')).to eq('/downloaded-file-path')
    end
  end
end
