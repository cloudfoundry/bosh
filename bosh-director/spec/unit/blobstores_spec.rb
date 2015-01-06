require 'spec_helper'

module Bosh::Director
  describe Blobstores do
    subject(:blobstores) { described_class.new(config) }
    let(:config) { Config.load_file(asset('test-director-config.yml')) }

    before { allow(Bosh::Blobstore::Client).to receive(:safe_create) }

    describe '#blobstore' do
      it 'provides the blobstore client' do
        blobstore_client = double('fake-blobstore-client')
        expect(Bosh::Blobstore::Client)
          .to receive(:safe_create)
          .with('simple', {
            'endpoint' => 'http://127.0.0.1',
            'user'     => 'admin',
            'password' => nil,
          })
          .and_return(blobstore_client)
        expect(blobstores.blobstore).to eq(blobstore_client)
      end
    end

    describe '#backup_destination' do
      it 'provides the blobstore client' do
        blobstore_client = double('fake-blobstore-client')
        expect(Bosh::Blobstore::Client)
          .to receive(:safe_create)
          .with('s3', {
            'bucket_name' => 'foo',
            'access_key_id' => 'asdf',
            'secret_access_key' => 'zxcv',
          })
          .and_return(blobstore_client)
        expect(blobstores.backup_destination).to eq(blobstore_client)
      end

      context 'when no backup blobstore is specified' do
        let(:config_hash) do
          {
            'blobstore' => {
              'provider' => 's3',
              'options' => {
                'bucket_name' => 'foo',
                'access_key_id' => 'asdf',
                'secret_access_key' => 'zxcv'
              }
            }
          }
        end
        let(:config) { Config.load_hash(config_hash) }

        it 'raises an exception' do
          expect {
            blobstores.backup_destination
          }.to raise_error('No backup destination configured')
        end
      end
    end
  end
end
