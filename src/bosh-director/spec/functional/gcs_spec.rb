require 'tempfile'
require 'net/http'

require 'erb'
require 'tempfile'
require 'bosh/director'
require_relative 'blobstore_shared_examples'

module Bosh::Blobstore
  describe GcscliBlobstoreClient do

    let(:credentials_source) do
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
            credentials_source: credentials_source,
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
            credentials_source: credentials_source,
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
    end

  end
end
