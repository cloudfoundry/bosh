require 'spec_helper'

module Bosh::Blobstore
  describe S3BlobstoreClient do
    describe 'interface' do
      subject do
        s3_blobstore(
          encryption_key: 'bla',
          bucket_name: 'test',
          access_key_id: 'KEY',
          secret_access_key: 'SECRET'
        )
      end

      it_implements_base_client_interface
    end

    let(:s3) { double(AWS::S3) }

    def s3_blobstore(options)
      allow(AWS::S3).to receive(:new).and_return(s3)
      S3BlobstoreClient.new(options)
    end

    describe 'options' do
      it 'should support symbols as option keys' do
        options = { bucket_name: 'test',
                    access_key_id: 'KEY',
                    secret_access_key: 'SECRET' }

        expect(s3_blobstore(options).bucket_name).to eq 'test'
      end

      it 'should support strings as option keys' do
        options = { 'bucket_name' => 'test',
                    'access_key_id' => 'KEY',
                    'secret_access_key' => 'SECRET' }

        expect(s3_blobstore(options).bucket_name).to eq 'test'
      end

      it 'should raise an error if using simple and encryption' do
        options = { 'bucket_name' => 'test',
                    'encryption_key' => 'KEY' }
        expect { s3_blobstore(options) }.to raise_error(
          BlobstoreError, "can't use read-only with an encryption key")
      end

      it 'should be processed and passed to the AWS::S3 class' do
        options = { 'bucket_name' => 'test',
                    'access_key_id' => 'KEY',
                    'secret_access_key' => 'SECRET',
                    'endpoint' => 'https://s3.example.com' }

        expect(AWS::S3).to receive(:new).
          with(access_key_id: 'KEY',
               secret_access_key: 'SECRET',
               use_ssl: true,
               port: 443,
               s3_endpoint: 's3.example.com').
          and_return(s3)

        S3BlobstoreClient.new(options)
      end
    end

    describe '#create' do
      subject(:client) { s3_blobstore(options) }

      context 'encrypted' do
        let(:options) do
          {
            bucket_name: 'test',
            access_key_id: 'KEY',
            secret_access_key: 'SECRET',
            encryption_key: 'kjahsdjahsgdlahs'
          }
        end

        it 'should encrypt' do
          expect(client).to receive(:store_in_s3) do |path, id|
            expect(File.open(path).read).to_not eq('foobar')
          end
          client.create('foobar')
        end
      end

      context 'unencrypted' do
        let(:options) do
          {
            bucket_name: 'test',
            access_key_id: 'KEY',
            secret_access_key: 'SECRET'
          }
        end

        it 'should not encrypt when key is missing' do
          expect(client).to_not receive(:encrypt_file)
          expect(client).to receive(:store_in_s3)
          client.create('foobar')
        end

        it 'should take a string as argument' do
          expect(client).to receive(:store_in_s3)
          client.create('foobar')
        end

        it 'should take a file as argument' do
          expect(client).to receive(:store_in_s3)
          file = File.open(asset('file'))
          client.create(file)
        end

        it 'should accept object id suggestion' do
          expect(client).to receive(:store_in_s3) do |_, id|
            expect(id).to eq('foobar')
          end
          file = File.open(asset('file'))
          client.create(file, 'foobar')
        end

        it 'should raise an error if the same object id is used' do
          expect(client).to receive(:get_object_from_s3).and_return(double('s3_object', exist?: true))

          expect { client.create(File.open(asset('file')), 'foobar') }.to raise_error BlobstoreError
        end
      end

      context 'with option folder' do
        let(:options) do
          {
            bucket_name: 'test',
            folder: 'folder',
            access_key_id: 'KEY',
            secret_access_key: 'SECRET',
          }
        end

        it 'should store to folder' do
          expect(client).to receive(:store_in_s3) do |_, id|
            expect(id).to eq('folder/foobar')
          end
          file = File.open(asset('file'))
          client.create(file, 'foobar')
        end
      end

      context 'with read-only access' do
        let(:options) { { bucket_name: 'fake-bucket' } }

        it 'raises an error' do
          expect {
            client.create('fake-oid')
          }.to raise_error(BlobstoreError, 'unsupported action')
        end
      end
    end

    describe '#get' do
      let(:options) do
        {
          bucket_name: 'test',
          access_key_id: 'KEY',
          secret_access_key: 'SECRET'
        }
      end
      let(:client) { s3_blobstore(options) }

      it 'should raise an error if the object is missing' do
        allow(client).to receive(:get_from_s3).and_raise AWS::S3::Errors::NoSuchKey.new(nil, nil)

        expect { client.get('missing-oid') }.to raise_error BlobstoreError
      end

      context 'unencrypted' do
        it 'should get an object' do
          blob = double('blob')
          expect(blob).to receive(:read).and_yield('foooo')
          expect(client).to receive(:get_object_from_s3).and_return(blob)
          expect(client.get('foooo')).to eq 'foooo'
        end
      end

      context 'with option folder' do
        let(:options) do
          {
            bucket_name: 'test',
            folder: 'folder',
            access_key_id: 'KEY',
            secret_access_key: 'SECRET',
          }
        end
        let(:client) { s3_blobstore(options) }

        it 'should get from folder' do
          blob = double('blob')
          expect(blob).to receive(:read).and_yield('foooo')
          expect(client).to receive(:get_object_from_s3).with('folder/foooo').and_return(blob)
          expect(client.get('foooo')).to eq('foooo')
        end
      end
    end

    describe '#exists?' do
      let(:options) do
        {
          encryption_key: 'bla',
          bucket_name: 'test',
          access_key_id: 'KEY',
          secret_access_key: 'SECRET'
        }
      end
      let(:client) { s3_blobstore(options) }
      let(:blob) { double(AWS::S3::S3Object) }

      it 'should return true if the object already exists' do
        expect(client).to receive(:get_object_from_s3).with('fake-oid').and_return(blob)
        expect(blob).to receive(:exists?).and_return(true)
        expect(client.exists?('fake-oid')).to be(true)
      end

      it 'should return false if the object does not exist' do
        expect(client).to receive(:get_object_from_s3).with('fake-oid').and_return(blob)
        expect(blob).to receive(:exists?).and_return(false)
        expect(client.exists?('fake-oid')).to be(false)
      end

      context 'without folder options' do
        let(:options) { { bucket_name: 'fake-bucket' } }

        it 'should pass through to simple.object_exists? for #exists?' do
          expect(client.simple).to receive(:exists?).with('fake-oid')
          client.exists?('fake-oid')
        end
      end

      context 'with folder options' do
        let(:options) { { bucket_name: 'fake-bucket', folder: 'fake-folder' } }

        it 'should pass through to simple.object_exists? for #exists? with folder' do
          expect(client.simple).to receive(:exists?).with('fake-folder/fake-oid')
          client.exists?('fake-oid')
        end
      end
    end

    describe '#delete' do
      subject(:client) { s3_blobstore(options) }

      context 'without folder option' do
        let(:options) do
          {
            encryption_key: 'bla',
            bucket_name: 'test',
            access_key_id: 'KEY',
            secret_access_key: 'SECRET'
          }
        end

        let(:blob) { double(AWS::S3::S3Object) }

        it 'should delete an object' do
          allow(blob).to receive_messages(exists?: true)

          expect(client).to receive(:get_object_from_s3).with('fake-oid').and_return(blob)
          expect(blob).to receive(:delete)
          client.delete('fake-oid')
        end

        it 'should raise an error when the object is missing' do
          allow(blob).to receive_messages(exists?: false)

          expect(client).to receive(:get_object_from_s3).with('fake-oid').and_return(blob)

          expect { client.delete('fake-oid') }.to raise_error BlobstoreError, 'no such object: fake-oid'
        end
      end

      context 'with option folder' do
        let(:options) do
          {
            folder: 'folder',
            bucket_name: 'test',
            access_key_id: 'KEY',
            secret_access_key: 'SECRET'
          }
        end

        let(:blob) { double(AWS::S3::S3Object) }

        it 'should delete an object' do
          allow(blob).to receive_messages(exists?: true)

          expect(client).to receive(:get_object_from_s3).with('folder/fake-oid').and_return(blob)
          expect(blob).to receive(:delete)
          client.delete('fake-oid')
        end
      end

      context 'with read-only access' do
        let(:options) { { bucket_name: 'fake-bucket' } }

        it 'raises an error' do
          expect {
            client.delete('fake-oid')
          }.to raise_error(BlobstoreError, 'unsupported action')
        end
      end
    end
  end
end
