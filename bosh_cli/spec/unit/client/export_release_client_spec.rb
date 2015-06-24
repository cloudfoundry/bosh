require 'json'
require 'spec_helper'
require 'cli/client/export_release_client'

describe Bosh::Cli::Client::ExportReleaseClient do
  subject(:client) { described_class.new(director) }
  let(:director) { instance_double('Bosh::Cli::Client::Director') }

  describe '#export' do
    it 'calls the director request_and_track method with the correct parameters' do
      allow(director).to receive(:request_and_track)
      client.export('best-deployment-evar', 'release', '1', 'centos-7', '0000')

      expected = JSON.dump(
          deployment_name: 'best-deployment-evar',
          release_name: 'release',
          release_version: '1',
          stemcell_os: 'centos-7',
          stemcell_version: '0000',
      )
      expect(director).to have_received(:request_and_track).with(
          :post,
          '/releases/export',
          { content_type: 'application/json', payload: expected },
      )
    end
  end
end
