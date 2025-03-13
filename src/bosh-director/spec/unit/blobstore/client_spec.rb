require 'spec_helper'

module Bosh::Director::Blobstore
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

        it 'returns s3cli client' do
          allow(Kernel).to receive(:system).with("/path", "--v", {:out => "/dev/null", :err => "/dev/null"}).and_return(true)
          expect(Client.create('s3cli', {
              access_key_id: 'foo',
              secret_access_key: 'bar',
              s3cli_path: '/path'
          })).to be_instance_of(S3cliBlobstoreClient)
        end

        it 'returns gcscli client' do
          allow(Kernel).to receive(:system).with("/path", "--v", {:out => "/dev/null", :err => "/dev/null"}).and_return(true)
          expect(Client.create('gcscli', {
              gcscli_path: '/path'
          })).to be_instance_of(GcscliBlobstoreClient)
        end

        it 'returns davcli client' do
          allow(Kernel).to receive(:system).with("/path", "-v", {:out => "/dev/null", :err => "/dev/null"}).and_return(true)
          expect(Client.create('davcli', {
            user: 'foo',
            password: 'bar',
            endpoint: 'zaksoup.com',
            davcli_path: '/path'
          })).to be_instance_of(DavcliBlobstoreClient)
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
          client = described_class.safe_create('s3cli',{
            access_key_id: 'foo',
            secret_access_key: 'bar',
            s3cli_path: true,
          })
          expect(client).to be_an_instance_of(RetryableBlobstoreClient)
        end

        it 'makes retryable client with s3 client' do
          wrapped_client = instance_double('Bosh::Director::Blobstore::S3cliBlobstoreClient')
          expect(S3cliBlobstoreClient)
            .to receive(:new)
            .and_return(wrapped_client)

          sha1_verifiable_client = instance_double('Bosh::Director::Blobstore::Sha1VerifiableBlobstoreClient')
          expect(Sha1VerifiableBlobstoreClient)
            .to receive(:new)
            .with(wrapped_client, per_spec_logger)
            .and_return(sha1_verifiable_client)

          retryable = instance_double('Bosh::Retryable')
          expect(Bosh::Retryable)
            .to receive(:new)
            .and_return(retryable)

          retryable_client = instance_double('Bosh::Director::Blobstore::RetryableBlobstoreClient')
          expect(RetryableBlobstoreClient)
            .to receive(:new)
            .with(sha1_verifiable_client, retryable)
            .and_return(retryable_client)

          expect(described_class.safe_create('s3cli', {
            access_key_id: 'foo',
            secret_access_key: 'bar',
            s3cli_path: true,
          })).to eq(retryable_client)
        end

        it 'makes retryable client with gcs client' do
          wrapped_client = instance_double('Bosh::Director::Blobstore::GcscliBlobstoreClient')
          expect(GcscliBlobstoreClient)
            .to receive(:new)
            .and_return(wrapped_client)

          sha1_verifiable_client = instance_double('Bosh::Director::Blobstore::Sha1VerifiableBlobstoreClient')
          expect(Sha1VerifiableBlobstoreClient)
            .to receive(:new)
            .with(wrapped_client, per_spec_logger)
            .and_return(sha1_verifiable_client)

          retryable = instance_double('Bosh::Retryable')
          expect(Bosh::Retryable)
            .to receive(:new)
            .and_return(retryable)

          retryable_client = instance_double('Bosh::Director::Blobstore::RetryableBlobstoreClient')
          expect(RetryableBlobstoreClient)
            .to receive(:new)
            .with(sha1_verifiable_client, retryable)
            .and_return(retryable_client)

          expect(described_class.safe_create('gcscli', {
            access_key_id: 'foo',
            secret_access_key: 'bar',
            gcscli_path: true,
          })).to eq(retryable_client)
        end

        it 'makes retryable object with default options' do
          expect(Bosh::Retryable)
            .to receive(:new)
            .with(tries: 6, sleep: 2.0, on: [BlobstoreError])
            .and_call_original
          described_class.safe_create('s3cli', {
            access_key_id: 'foo',
            secret_access_key: 'bar',
            s3cli_path: true,
          })
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
