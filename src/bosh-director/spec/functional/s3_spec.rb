require 'tempfile'
require 'net/http'

require 'erb'
require 'tempfile'
require 'bosh/director'
require_relative 'blobstore_shared_examples'

module Bosh::Blobstore
  describe S3cliBlobstoreClient do
    let(:access_key_id) do
      key = ENV['AWS_ACCESS_KEY_ID']
      raise 'need to set AWS_ACCESS_KEY_ID environment variable' unless key
      key
    end

    let(:secret_access_key) do
      key = ENV['AWS_SECRET_ACCESS_KEY']
      raise 'need to set AWS_SECRET_ACCESS_KEY environment variable' unless key
      key
    end

    let(:s3_host) do
      ENV.fetch('S3_HOST', 's3.amazonaws.com')
    end

    let(:s3cli_path) do
      Dir.glob(File.join(File.dirname(__FILE__), "../../../../blobs/s3cli/", "s3cli-*-linux-amd64")).first
    end

    let(:bucket_name) do
      key = ENV['S3_BUCKET_NAME']
      raise 'need to set S3_BUCKET_NAME environment variable' unless key
      key
    end

    let(:logger) {Logging::Logger.new('test-logger')}

    before do
      allow(Bosh::Director::Config).to receive(:logger).and_return(logger)
    end

    context 'External Endpoint', aws_s3: true do
      let(:s3_options) do
        {
          bucket_name: bucket_name,
          access_key_id: access_key_id,
          secret_access_key: secret_access_key,
          host: 's3-external-1.amazonaws.com',
          credentials_source: 'static',
          s3cli_path: s3cli_path
        }
      end

      let(:s3) do
        Client.create('s3cli', s3_options)
      end

      after(:each) do
        s3.delete(@oid) if @oid
      end

      describe 'get object' do
        it 'should save to a file' do
          @oid = s3.create('foobar')
          file = Tempfile.new('contents')
          s3.get(@oid, file)
          file.rewind
          expect(file.read).to eq 'foobar'
        end

        it 'should save a file using v2 signature version' do
          custom_s3 = Client.create('s3cli', s3_options.merge({signature_version: "2"}))
          @oid = custom_s3.create('foobar')
          file = Tempfile.new('contents')
          custom_s3.get(@oid, file)
          file.rewind
          expect(file.read).to eq 'foobar'
        end

        it 'should save a file using v4 signature version' do
          custom_s3 = Client.create('s3cli', s3_options.merge({signature_version: "4"}))
          @oid = custom_s3.create('foobar')
          file = Tempfile.new('contents')
          custom_s3.get(@oid, file)
          file.rewind
          expect(file.read).to eq 'foobar'
        end
      end
    end

    context 'External Frankfurt Endpoint', aws_frankfurt_s3: true do
      let(:bucket_name) do
        key = ENV['S3_FRANKFURT_BUCKET_NAME']
        raise 'need to set S3_FRANKFURT_BUCKET_NAME environment variable' unless key
        key
      end

      let(:s3_options) do
        {
          bucket_name: bucket_name,
          access_key_id: access_key_id,
          secret_access_key: secret_access_key,
          host: 's3.eu-central-1.amazonaws.com',
          region: 'eu-central-1',
          credentials_source: 'static',
          s3cli_path: s3cli_path
        }
      end

      let(:s3) do
        Client.create('s3cli', s3_options)
      end

      after(:each) do
        s3.delete(@oid) if @oid
      end

      describe 'get object' do
        it 'should save to a file' do
          @oid = s3.create('foobar')
          file = Tempfile.new('contents')
          s3.get(@oid, file)
          file.rewind
          expect(file.read).to eq 'foobar'
        end

        context 'when forcing the signature_version to v2' do
          it 'should not be able to save a file' do
            s3 = Client.create('s3cli', s3_options.merge({'signature_version' => "2"}))
            expect {
              @oid = s3.create('foobar')
            }.to raise_error(/Upload failed: InvalidRequest: The authorization mechanism you have provided is not supported. Please use AWS4-HMAC-SHA256/)
          end
        end
      end
    end

    context 'Frankfurt Region', aws_frankfurt_s3: true do
      let(:bucket_name) do
        key = ENV['S3_FRANKFURT_BUCKET_NAME']
        raise 'need to set S3_FRANKFURT_BUCKET_NAME environment variable' unless key
        key
      end

      let(:s3_options) do
        {
          bucket_name: bucket_name,
          access_key_id: access_key_id,
          secret_access_key: secret_access_key,
          region: 'eu-central-1',
          credentials_source: 'static',
          s3cli_path: s3cli_path
        }
      end

      let(:s3) do
        Client.create('s3cli', s3_options)
      end

      after(:each) do
        s3.delete(@oid) if @oid
      end

      describe 'get object' do
        it 'should save to a file' do
          @oid = s3.create('foobar')
          file = Tempfile.new('contents')
          s3.get(@oid, file)
          file.rewind
          expect(file.read).to eq 'foobar'
        end
      end
    end

    context 'General S3', general_s3: true do
      context 'with force_path_style=true' do
        let(:s3_options) do
          {
            bucket_name: bucket_name,
            access_key_id: access_key_id,
            secret_access_key: secret_access_key,
            s3_force_path_style: true,
            host: s3_host,
            credentials_source: 'static',
            s3cli_path: s3cli_path
          }
        end

        let(:s3) do
          Client.create('s3cli', s3_options)
        end

        after(:each) do
          s3.delete(@oid) if @oid
        end

        describe 'get object' do
          it 'should save to a file' do
            @oid = s3.create('foobar')
            file = Tempfile.new('contents')
            s3.get(@oid, file)
            file.rewind
            expect(file.read).to eq 'foobar'
          end
        end
      end

      context 'Read/Write' do
        let(:s3_options) do
          {
            bucket_name: bucket_name,
            access_key_id: access_key_id,
            secret_access_key: secret_access_key,
            host: s3_host,
            credentials_source: 'static',
            s3cli_path: s3cli_path
          }
        end

        let(:s3) do
          Client.create('s3cli', s3_options)
        end

        it_behaves_like 'any blobstore client' do
          let(:blobstore) { s3 }
        end
      end
    end

    # TODO: Make simple blobstore work with s3-compatible services
    context 'Read-Only', aws_s3: true do
      let(:s3_options) do
        {
          bucket_name: bucket_name,
          s3cli_path: s3cli_path,
          credentials_source: 'none'
        }
      end

      let(:s3) do
        Client.create('s3cli', s3_options)
      end

      let(:contents) do
        'foobar'
      end

      describe 'get object' do
        it 'should save to a file' do
          file = Tempfile.new('contents')
          s3.get('public', file)
          file.rewind
          expect(file.read).to eq contents
        end

        it 'should return the contents' do
          expect(s3.get('public')).to eq contents
        end

        it 'should raise an error when the object is missing' do
          expect { s3.get('nonexistent-key') }.to raise_error NotFound, /Blobstore object 'nonexistent-key' not found/
        end
      end

      describe 'create object' do
        it 'should raise an error' do
          expect { s3.create(contents) }.to raise_error BlobstoreError, /performing operation put: the client operates in read only mode./
        end
      end

      describe 'delete object' do
        context 'when the key exists' do
          it 'should raise an error' do
            expect { s3.delete('public') }.to raise_error BlobstoreError, /performing operation delete: the client operates in read only mode./
          end
        end

        context 'when the key does not exist' do
          it 'should raise an error' do
            expect { s3.delete('nonexistent-key') }.to raise_error BlobstoreError, /performing operation delete: the client operates in read only mode./
          end
        end
      end

      describe 'object exists?' do
        it 'the object should exist' do
          expect(s3.exists?('public')).to be true
        end
      end
    end
  end
end
