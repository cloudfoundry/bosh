require 'spec_helper'
require 'tempfile'
require 'net/http'

module Bosh::Blobstore

  describe S3BlobstoreClient do
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

    let(:bucket_name) do
      key = ENV['S3_BUCKET_NAME']
      raise 'need to set S3_BUCKET_NAME environment variable' unless key
      key
    end

    context 'External Endpoint', aws_s3: true do
      let(:s3_options) do
        {
          bucket_name: bucket_name,
          access_key_id: access_key_id,
          secret_access_key: secret_access_key,
          host: 's3-external-1.amazonaws.com'
        }
      end

      let(:s3) do
        Client.create('s3', s3_options)
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
          custom_s3 = Client.create('s3', s3_options.merge({signature_version: "2"}))
          @oid = custom_s3.create('foobar')
          file = Tempfile.new('contents')
          custom_s3.get(@oid, file)
          file.rewind
          expect(file.read).to eq 'foobar'
        end

        it 'should save a file using v4 signature version' do
          custom_s3 = Client.create('s3', s3_options.merge({signature_version: "4"}))
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
          host: 's3-external-1.amazonaws.com',
          region: 'eu-central-1'
        }
      end

      let(:s3) do
        Client.create('s3', s3_options)
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
            s3 = Client.create('s3', s3_options.merge({'signature_version' => "2"}))
            expect {
              @oid = s3.create('foobar')
            }.to raise_error(/The authorization mechanism you have provided is not supported/)
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
          region: 'eu-central-1'
        }
      end

      let(:s3) do
        Client.create('s3', s3_options)
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
            host: s3_host
          }
        end

        let(:s3) do
          Client.create('s3', s3_options)
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
            host: s3_host
          }
        end

        let(:s3) do
          Client.create('s3', s3_options)
        end

        after(:each) do
          s3.delete(@oid) if @oid
          s3.delete(@oid2) if @oid2
        end

        describe 'unencrypted' do
          describe 'store object' do
            it 'should upload a file' do
              Tempfile.open('foo') do |file|
                @oid = s3.create(file)
                expect(@oid).to_not be_nil
              end
            end

            it 'should upload a string' do
              @oid = s3.create('foobar')
              expect(@oid).to_not be_nil
            end

            it 'should handle uploading the same object twice' do
              @oid = s3.create('foobar')
              expect(@oid).to_not be_nil
              @oid2 = s3.create('foobar')
              expect(@oid2).to_not be_nil
              expect(@oid).to_not eq @oid2
            end
          end

          describe 'get object' do
            it 'should save to a file' do
              @oid = s3.create('foobar')
              file = Tempfile.new('contents')
              s3.get(@oid, file)
              file.rewind
              expect(file.read).to eq 'foobar'
            end

            it 'should return the contents' do
              @oid = s3.create('foobar')

              expect(s3.get(@oid)).to eq 'foobar'
            end

            it 'should raise an error when the object is missing' do
              id = 'foooooo'

              expect { s3.get(id) }.to raise_error BlobstoreError, "S3 object '#{id}' not found"
            end
          end

          describe 'delete object' do
            it 'should delete an object' do
              @oid = s3.create('foobar')

              expect { s3.delete(@oid) }.to_not raise_error

              @oid = nil
            end

            it "should raise an error when object doesn't exist" do
              expect { s3.delete('foobar') }.to raise_error Bosh::Blobstore::NotFound, /Object 'foobar' is not found/
            end
          end

          describe 'object exists?' do
            it 'should exist after create' do
              @oid = s3.create('foobar')
              expect(s3.exists?(@oid)).to be true
            end

            it 'should return false if object does not exist' do
              expect(s3.exists?('foobar-fake')).to be false
            end
          end

        end
      end
    end

    # TODO: Make simple blobstore work with s3-compatible services
    context 'Read-Only', aws_s3: true do
      let(:s3_options) do
        { bucket_name: bucket_name }
      end

      let(:s3) do
        Client.create('s3', s3_options)
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
          expect { s3.get('foooooo') }.to raise_error BlobstoreError, /Could not fetch object/
        end
      end

      describe 'create object' do
        it 'should raise an error' do
          expect { s3.create(contents) }.to raise_error BlobstoreError, 'unsupported action'
        end
      end

      describe 'delete object' do
        it 'should raise an error' do
          expect { s3.delete('public') }.to raise_error BlobstoreError, 'unsupported action'
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
