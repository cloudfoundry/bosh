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

    describe '.safe_create' do
      context 'with known provider' do
        it 'returns retryable client' do
          client = described_class.safe_create('simple', {})
          client.should be_an_instance_of(RetryableBlobstoreClient)
        end

        it 'makes retryable client with simple client' do
          wrapped_client = instance_double('Bosh::Blobstore::SimpleBlobstoreClient')
          SimpleBlobstoreClient
            .should_receive(:new)
            .and_return(wrapped_client)

          sha1_verifiable_client = instance_double('Bosh::Blobstore::Sha1VerifiableBlobstoreClient')
          Sha1VerifiableBlobstoreClient
            .should_receive(:new)
            .with(wrapped_client)
            .and_return(sha1_verifiable_client)

          retryable = instance_double('Bosh::Retryable')
          Bosh::Retryable
            .should_receive(:new)
            .and_return(retryable)

          retryable_client = instance_double('Bosh::Blobstore::RetryableBlobstoreClient')
          RetryableBlobstoreClient
            .should_receive(:new)
            .with(sha1_verifiable_client, retryable)
            .and_return(retryable_client)

          expect(described_class.safe_create('simple', {})).to eq(retryable_client)
        end

        it 'makes retryable client with simple client' do
          options = { 'fake-key' => 'fake-value' }
          SimpleBlobstoreClient.should_receive(:new).with(options).and_call_original
          described_class.safe_create('simple', options)
        end

        it 'makes retryable object with default options' do
          Bosh::Retryable
            .should_receive(:new)
            .with(tries: 3, sleep: 0.5, on: [BlobstoreError])
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
