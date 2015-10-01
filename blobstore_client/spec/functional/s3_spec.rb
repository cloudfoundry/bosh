require 'spec_helper'
require 'tempfile'
require 'net/http'

module Bosh::Blobstore

  describe S3BlobstoreClient, s3_credentials: true do
    def access_key_id
      key = ENV['AWS_ACCESS_KEY_ID']
      raise 'need to set AWS_ACCESS_KEY_ID environment variable' unless key
      key
    end

    def secret_access_key
      key = ENV['AWS_SECRET_ACCESS_KEY']
      raise 'need to set AWS_SECRET_ACCESS_KEY environment variable' unless key
      key
    end

    attr_reader :bucket_name

    before(:all) do
      s3 = AWS::S3.new(
        access_key_id: access_key_id,
        secret_access_key: secret_access_key,
        use_ssl: true,
        port: 443
      )

      @bucket_name = sprintf('bosh-blobstore-bucket-%08x', rand(2**32))

      @bucket = s3.buckets.create(@bucket_name, acl: :public_read)

      object = @bucket.objects['public']
      object.write('foobar', acl: :public_read)
    end

    after(:all) do
      @bucket.delete!
    end

    context 'Read/Write' do
      let(:s3_options) do
        {
          bucket_name: bucket_name,
          access_key_id: access_key_id,
          secret_access_key: secret_access_key,
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
            Tempfile.new('foo') do |file|
              expect(s3.create(file)).to_not be_nil
            end
          end

          it 'should upload a string' do
            expect(s3.create('foobar')).to_not be_nil
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
      end

      context 'encrypted' do
        let(:unencrypted_s3) do
          s3
        end

        let(:encrypted_s3) do
          Client.create('s3', s3_options.merge(encryption_key: 'kjahsdjahsgdlahs'))
        end

        describe 'backwards compatibility' do
          it 'should work when a blob was uploaded by blobstore_client 0.5.0' do
            @oid = unencrypted_s3.create(File.read(asset('encrypted_blob_from_blobstore_client_0.5.0')))
            expect(encrypted_s3.get(@oid)).to eq 'skadim vadar'
          end
        end

        describe 'create object' do
          it 'should be encrypted' do
            @oid = encrypted_s3.create('foobar')
            expect(encrypted_s3.get(@oid)).to eq 'foobar'
          end
        end
      end
    end

    context 'Read-Only' do
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
    end
  end
end
