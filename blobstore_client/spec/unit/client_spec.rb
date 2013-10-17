require 'spec_helper'

module Bosh::Blobstore
  describe Client do
    describe '.create' do
      context 'with known client provider' do
        it 'returns local client' do
          Dir.mktmpdir do |tmp|
            Client.create(
              'local',
              { blobstore_path: tmp },
            ).should be_instance_of(LocalClient)
          end
        end

        it 'returns simple client' do
          Client.create('simple', {}).should be_instance_of(SimpleBlobstoreClient)
        end

        it 'returns atmos client' do
          Client.create('atmos', {}).should be_instance_of(AtmosBlobstoreClient)
        end

        it 'returns s3 client' do
          Client.create('s3', {
            access_key_id: 'foo',
            secret_access_key: 'bar'
          }).should be_instance_of(S3BlobstoreClient)
        end

        it 'should pick S3 provider when S3 is used without credentials' do
          Client.create('s3', bucket_name: 'foo').should be_instance_of(S3BlobstoreClient)
        end

        it 'returns swift client' do
          Client.create('swift', {}).should be_instance_of(SwiftBlobstoreClient)
        end
      end

      context 'with unknown client provider' do
        it 'raise an exception' do
          expect {
            Client.create('fake-unknown-provider', {})
          }.to raise_error(/^Unknown client provider 'fake-unknown-provider'/)
        end
      end
    end
  end
end
