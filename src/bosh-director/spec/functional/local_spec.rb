require 'tempfile'
require 'net/http'

require 'bosh/director'
require_relative 'blobstore_shared_examples'

module Bosh::Blobstore
  describe LocalClient do
    let(:logger) { Logging::Logger.new('test-logger') }

    before do
      allow(Bosh::Director::Config).to receive(:logger).and_return(logger)
    end

    context 'Local filesystem blobstore', local_blobstore_integration: true do
      let(:options) do
        { blobstore_path: Dir.mktmpdir('blobstore') }
      end

      it_behaves_like 'any blobstore client' do
        let(:blobstore) { Client.create('local', options) }
      end
    end
  end
end
