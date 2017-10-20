require 'tempfile'
require 'net/http'

require 'erb'
require 'tempfile'
require 'bosh/director'
require_relative 'blobstore_shared_examples'

RSpec::Matchers.define :eventually_error do |block|
  supports_block_expectations

  match do |actual|
    begin
      Timeout.timeout(10) do
        first, second = nil, nil
        until values_match?(first, second)
          begin
            block.call
          rescue Exception => err
            first = err
          end
          begin
            actual.call
          rescue Exception => err2
            second = err2
          end
          sleep 0.5
        end
        return true
      end
    rescue Timeout::Error
      return false
    end
  end

  failure_message do |_actual|
    block.call.failure_message
  end
end

module Bosh::Blobstore
  describe GcscliBlobstoreClient do

    let(:service_account_file) do
      key = ENV['GCS_SERVICE_ACCOUNT_KEY']
      raise 'need to set GCS_SERVICE_ACCOUNT_KEY environment variable' unless key
      key
    end

    let(:gcscli_path) do
      Dir.glob(File.join(File.dirname(__FILE__), "../../../../blobs/bosh-gcscli/", "bosh-gcscli-*-linux-amd64")).first
    end

    let(:bucket_name) do
      key = ENV['GCS_BUCKET_NAME']
      raise 'need to set GCS_BUCKET_NAME environment variable' unless key
      key
    end

    let(:logger) {Logging::Logger.new('test-logger')}

    before do
      allow(Bosh::Director::Config).to receive(:logger).and_return(logger)
    end

    context 'General GCS', general_gcs: true do
      context 'with basic configuration' do
        let(:gcs_options) do
          {
            bucket_name: bucket_name,
            credentials_source: "static",
            json_key: service_account_file,
            gcscli_path: gcscli_path
          }
        end

        let(:gcs) do
          Client.create('gcscli', gcs_options)
        end

        after(:each) do
          gcs.delete(@oid) if @oid
        end

        describe 'get object' do
          it 'should save to a file' do
            @oid = gcs.create('foobar')
            file = Tempfile.new('contents')
            gcs.get(@oid, file)
            file.rewind
            expect(file.read).to eq 'foobar'
          end
        end
      end

      context 'Read/Write' do
        let(:gcs_options) do
          {
            bucket_name: bucket_name,
            credentials_source: "static",
            json_key: service_account_file,
            gcscli_path: gcscli_path
          }
        end

        let(:gcs) do
          Client.create('gcscli', gcs_options)
        end

        it_behaves_like 'any blobstore client' do
          let(:blobstore) { gcs }
        end
      end

      context 'Encrypted Read/Write' do
        let(:gcs_options) do
          {
            bucket_name: bucket_name,
            credentials_source: "static",
            json_key: service_account_file,
            encryption_key: "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=",
            gcscli_path: gcscli_path
          }
        end
        let(:invalid_gcs_options) do
          {
            bucket_name: bucket_name,
            credentials_source: "static",
            json_key: service_account_file,
            gcscli_path: gcscli_path
          }
        end

        let(:gcs) do
          Client.create('gcscli', gcs_options)
        end

        after(:each) do
          gcs.delete(@oid) if @oid
        end

        it_behaves_like 'any blobstore client' do
          let(:blobstore) { gcs }
        end

        let(:invalid_gcs) do
          Client.create('gcscli', invalid_gcs_options)
        end

        describe 'get object without key' do
          it 'should raise an error' do
            @oid = gcs.create('foobar')
            file = Tempfile.new('contents')
            expect { invalid_gcs.get(@oid, file) }.to raise_error BlobstoreError, /ResourceIsEncryptedWithCustomerEncryptionKey/
          end
        end
      end
    end

    context 'Read-Only', general_gcs: true do
        let(:gcs_options) do
          {
            bucket_name: bucket_name,
            credentials_source: 'none',
            gcscli_path: gcscli_path
          }
        end

      let(:gcs) do
        Client.create('gcscli', gcs_options)
      end

      let(:contents) do
        'foobar'
      end

      describe 'get object' do
        it 'should save to a file' do
          file = Tempfile.new('contents')
          gcs.get('public', file)
          file.rewind
          expect(file.read).to eq contents
        end

        it 'should return the contents' do
          expect(gcs.get('public')).to eq contents
        end

        it 'should raise an error when the object is missing' do
          expect { gcs.get('nonexistent-key') }.to eventually_error -> { raise_error NotFound, /Blobstore object 'nonexistent-key' not found/ }
        end
      end

      describe 'create object' do
        it 'should raise an error' do
          expect { gcs.create(contents) }.to eventually_error -> { raise_error BlobstoreError, /performing operation put: the client operates in read only mode./ }
        end
      end

      describe 'delete object' do
        context 'when the key exists' do
          it 'should raise an error' do
            expect { gcs.delete('public') }.to eventually_error -> { raise_error BlobstoreError, /performing operation delete: the client operates in read only mode./ }
          end
        end

        context 'when the key does not exist' do
          it 'should raise an error' do
            expect { gcs.delete('nonexistent-key') }.to eventually_error -> { raise_error BlobstoreError, /performing operation delete: the client operates in read only mode./ }
          end
        end
      end

      describe 'object exists?' do
        it 'the object should exist' do
          expect(gcs.exists?('public')).to be true
        end
      end
    end
  end
end
