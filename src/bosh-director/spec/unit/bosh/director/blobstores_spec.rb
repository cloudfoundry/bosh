require 'spec_helper'

module Bosh::Director
  describe Blobstores do
    let(:config) { instance_double(Config, blobstore_config: blobstore_config) }

    describe '#initialize' do
      context 'with known client provider' do
        context 'when provider is "local"' do
          let(:blobstore_config) do
            {
              'provider' => 'local',
              'options' => {
                blobstore_path: Dir.mktmpdir
              },
            }
          end

          it 'builds a local client' do
            expect(Blobstore::LocalClient).to receive(:new).with(blobstore_config['options'])

            Blobstores.new(config)
          end
        end

        context 'when provider is "s3cli"' do
          let(:blobstore_config) do
            { 'provider' => 's3cli',
              'options' => {
                access_key_id: 'foo',
                secret_access_key: 'bar',
                s3cli_path: '/path'
              },
            }
          end

          it 'returns s3cli client' do
            expect(Blobstore::S3cliBlobstoreClient).to receive(:new).with(blobstore_config['options'])

            Blobstores.new(config)
          end
        end

        context 'when provider is "gcs"' do
          let(:blobstore_config) do

            { 'provider' => 'gcscli',
              'options' => {
                gcscli_path: '/path'
              },
            }
          end
          it 'returns gcscli client' do
            expect(Blobstore::GcscliBlobstoreClient).to receive(:new).with(blobstore_config['options'])

            Blobstores.new(config)
          end
        end

        context 'when provider is "davcli"' do
          let(:blobstore_config) do

            { 'provider' => 'davcli',
              'options' => {
                user: 'foo',
                password: 'bar',
                endpoint: 'zaksoup.com',
                davcli_path: '/path'
              },
            }
          end

          it 'returns davcli client' do
            expect(Blobstore::DavcliBlobstoreClient).to receive(:new).with(blobstore_config['options'])

            Blobstores.new(config)
          end
        end
      end

      context 'with unknown client provider' do
        let(:blobstore_config) do
          {
            'provider' => 'fake-unknown-provider',
            'options' => {},
          }
        end

        it 'raise an exception' do
          expect {
            Blobstores.new(config)
          }.to raise_error(/^Unknown client provider 'fake-unknown-provider'/)
        end
      end
    end
  end
end
