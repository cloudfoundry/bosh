require 'spec_helper'

module Bosh::Director
  describe Blobstores do
    subject(:blobstores) { described_class.new(config) }
    let(:config) { Config.load_hash(SpecHelper.director_config_hash) }

    before { allow(Bosh::Director::Blobstore::Client).to receive(:safe_create) }

    describe '#blobstore' do
      it 'provides the blobstore client' do
        blobstore_client = double('fake-blobstore-client')
        expect(Bosh::Director::Blobstore::Client)
          .to receive(:safe_create)
          .with('davcli',
                { 'endpoint' => 'http://127.0.0.1',
                'user' => 'admin',
                'password' => nil,
                'davcli_path' => true })
          .and_return(blobstore_client)
        expect(blobstores.blobstore).to eq(blobstore_client)
      end
    end
  end
end
