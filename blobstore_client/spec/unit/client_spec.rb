require 'spec_helper'

module Bosh::Blobstore
  describe Client do
    describe '.create' do
      context 'with known client provider' do
        it 'returns local client' do
          Dir.mktmpdir do |tmp|
            expect(Client.create(
              'local',
              { blobstore_path: tmp },
            )).to be_instance_of(LocalClient)
          end
        end

        it 'returns simple client' do
          expect(Client.create('simple', {})).to be_instance_of(SimpleBlobstoreClient)
        end

        it 'returns s3 client' do
          expect(Client.create('s3', {
            access_key_id: 'foo',
            secret_access_key: 'bar'
          })).to be_instance_of(S3BlobstoreClient)
        end

        it 'should pick S3 provider when S3 is used without credentials' do
          expect(Client.create('s3', bucket_name: 'foo')).to be_instance_of(S3BlobstoreClient)
        end

        it 'returns swift client' do
          expect(Client.create('swift', {})).to be_instance_of(SwiftBlobstoreClient)
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

    describe '.safe_create' do
      context 'with known provider' do
        it 'returns retryable client' do
          client = described_class.safe_create('simple', {})
          expect(client).to be_an_instance_of(RetryableBlobstoreClient)
        end

        it 'makes retryable client with simple client' do
          wrapped_client = instance_double('Bosh::Blobstore::SimpleBlobstoreClient')
          expect(SimpleBlobstoreClient)
            .to receive(:new)
            .and_return(wrapped_client)

          sha1_verifiable_client = instance_double('Bosh::Blobstore::Sha1VerifiableBlobstoreClient')
          expect(Sha1VerifiableBlobstoreClient)
            .to receive(:new)
            .with(wrapped_client)
            .and_return(sha1_verifiable_client)

          retryable = instance_double('Bosh::Retryable')
          expect(Bosh::Retryable)
            .to receive(:new)
            .and_return(retryable)

          retryable_client = instance_double('Bosh::Blobstore::RetryableBlobstoreClient')
          expect(RetryableBlobstoreClient)
            .to receive(:new)
            .with(sha1_verifiable_client, retryable)
            .and_return(retryable_client)

          expect(described_class.safe_create('simple', {})).to eq(retryable_client)
        end

        it 'makes retryable client with simple client' do
          options = { 'fake-key' => 'fake-value' }
          expect(SimpleBlobstoreClient).to receive(:new).with(options).and_call_original
          described_class.safe_create('simple', options)
        end

        it 'makes retryable object with default options' do
          expect(Bosh::Retryable)
            .to receive(:new)
            .with(tries: 6, sleep: 2.0, on: [BlobstoreError])
            .and_call_original
          described_class.safe_create('simple', {})
        end
      end

      context 'with unknown provider' do
        it 'raise an exception' do
          expect {
            described_class.safe_create('fake-unknown-provider', {})
          }.to raise_error(/^Unknown client provider 'fake-unknown-provider'/)
        end
      end
    end
  end
end
