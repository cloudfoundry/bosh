require 'spec_helper'

module Bosh::Blobstore
  describe S3BlobstoreClient do
    subject(:client) { described_class.new(options) }
    let(:options) { {} }
    let(:default_options) do
      {
        bucket_name: 'test',
        access_key_id: 'KEY',
        secret_access_key: 'SECRET',
      }
    end

    before { allow(Aws::S3::Client).to receive(:new).and_return(s3) }
    let(:s3) { instance_double('Aws::S3::Client') }
    let(:blob) { instance_double('Aws::S3::Object') }

    before { allow(s3).to receive(:wait_until).and_return(true) }

    describe 'interface' do
      before do
        options.merge!(
          bucket_name: 'test',
          access_key_id: 'KEY',
          secret_access_key: 'SECRET',
        )
      end

      it_implements_base_client_interface
    end

    describe 'options' do
      let(:blob) { instance_double(Aws::S3::Object) }
      let(:s3_client) { instance_double(Aws::S3::Client) }
      before do
        allow(blob).to receive(:upload_file)
        allow(blob).to receive(:exists?)
        allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
        allow(s3_client).to receive(:list_objects)
      end

      context 'when advanced options are provided for customization' do
        let(:options) do
          default_options.merge({
              use_ssl: false,
              ssl_verify_peer: false,
              s3_multipart_threshold: 33333,
              port: 8080,
              host: 'our.userdefined.com',
              s3_force_path_style: true,
            })
        end

        it 'uses those options when building Aws::S3 client' do
          expect(Aws::S3::Object).to receive(:new).with(hash_including(
            bucket_name: 'test',
            endpoint: 'http://our.userdefined.com:8080',
            force_path_style: true,
            ssl_verify_peer: false,
            access_key_id: 'KEY',
            secret_access_key: 'SECRET',
          )).twice.and_return(blob)

          client.create_file('foo', 'file')
        end
      end

      context 'when advanced options are not provided for customization' do
        let(:options) { default_options }

        it 'uses default options when building Aws::S3 client' do
          expect(Aws::S3::Object).to receive(:new).with(
            key: 'foo',
            bucket_name: 'test',
            region: 'us-east-1',
            access_key_id: 'KEY',
            secret_access_key: 'SECRET',
            ssl_verify_peer: true,
            force_path_style: false,
            signature_version: 's3'
          ).twice.and_return(blob)

          client.create_file('foo', 'file')
        end
      end

      context 'when region has been set to nil' do
        let(:region) { nil }
        let(:options) { default_options.merge({region: region}) }

        it 'uses the default region' do
          expect(Aws::S3::Object).to receive(:new).with(
             key: 'fake-key',
             bucket_name: 'test',
             region: 'us-east-1',
             access_key_id: 'KEY',
             secret_access_key: 'SECRET',
             ssl_verify_peer: true,
             force_path_style: false,
             signature_version: 's3'
           ).twice.and_return(blob)

          client.create_file('fake-key', 'file')
        end
      end

      context 'when using a region that does not require v4' do
        let(:region) { 'us-east-1' }
        let(:options) { default_options.merge({region: region}) }

        it 'uses signature version v2' do
          expect(Aws::S3::Object).to receive(:new).with(
            hash_including(:signature_version => 's3')
          ).twice.and_return(blob)

          client.create_file('foo', 'file')
        end

        context 'when forcing v4 signature_version' do
          let(:options) { default_options.merge({region: region, signature_version: '4'}) }

          it 'uses signature version v4' do
            expect(Aws::S3::Object).to receive(:new).with(
              hash_excluding(:signature_version => 's3')
            ).twice.and_return(blob)

            client.create_file('foo', 'file')
          end
        end

        context 'when using invalid signature_version' do
          let(:options) { default_options.merge({region: region, signature_version: 'v4'}) }

          it 'uses signature version v2' do
            expect(Aws::S3::Object).to receive(:new).with(
            hash_including(:signature_version => 's3')
            ).twice.and_return(blob)

            client.create_file('foo', 'file')
          end
        end
      end

      context 'when using the eu-central-1 region' do
        let(:region) { 'eu-central-1' }
        let(:options) { default_options.merge({region: region}) }

        it 'uses signature version v4' do
          expect(Aws::S3::Object).to receive(:new).with(
            hash_excluding(:signature_version => 's3')
          ).twice.and_return(blob)

          client.create_file('foo', 'file')
        end

        context 'when forcing v2 signature_version' do
          let(:options) { default_options.merge({region: region, signature_version: '2'}) }

          it 'uses signature version v2' do
            expect(Aws::S3::Object).to receive(:new).with(
              hash_including(:signature_version => 's3')
            ).twice.and_return(blob)

            client.create_file('foo', 'file')
          end
        end

        context 'when using invalid signature_version' do
          let(:options) { default_options.merge({region: region, signature_version: 'v2'}) }

          it 'uses signature version v4' do
            expect(Aws::S3::Object).to receive(:new).with(
            hash_excluding(:signature_version => 's3')
            ).twice.and_return(blob)

            client.create_file('foo', 'file')
          end
        end
      end

      context 'when using the cn-north-1 region' do
        let(:region) { 'cn-north-1' }
        let(:options) { default_options.merge({region: region}) }

        it 'uses signature version v4' do
          expect(Aws::S3::Object).to receive(:new).with(
            hash_excluding(:signature_version => 's3')
          ).twice.and_return(blob)

          client.create_file('foo', 'file')
        end

        context 'when forcing v2 signature_version' do
          let(:options) { default_options.merge({region: region, signature_version: '2'}) }

          it 'uses signature version v2' do
            expect(Aws::S3::Object).to receive(:new).with(
              hash_including(:signature_version => 's3')
            ).twice.and_return(blob)

            client.create_file('foo', 'file')
          end
        end
      end
    end

    describe '#create' do
      subject(:client) { described_class.new(options) }

      let(:options) do
        {
          bucket_name: 'test',
          access_key_id: 'KEY',
          secret_access_key: 'SECRET'
        }
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
        blob = instance_double(Aws::S3::Object, exists?: true)
        allow(Aws::S3::Object).to receive(:new).and_return(blob)
        s3_client = instance_double(Aws::S3::Client)
        allow(Aws::S3::Client).to receive(:new).and_return(s3_client)

        allow(s3_client).to receive(:list_objects)

        expect {
          client.create(File.open(asset('file')), 'foobar')
        }.to raise_error(BlobstoreError, /foobar is already in use/)
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

      context 'with non existing blob' do
        let(:blob) { instance_double('Aws::S3::Object', exists?: false) }
        let(:s3_client) { instance_double('Aws::S3::Client') }
        let(:options) do
          {
            bucket_name: 'test',
            access_key_id: 'KEY',
            secret_access_key: 'SECRET',
          }
        end

        before do
          allow(Aws::S3::Object).to receive(:new).and_return(blob)
          allow(Aws::S3::Client).to receive(:new).and_return(s3_client)

          allow(blob).to receive(:upload_file)
          allow(s3_client).to receive(:list_objects)
        end

        it 'uses a proper content-type' do
          client.create('foobar', 'foobar')
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
      let(:client) { described_class.new(options) }
      let(:blob) { instance_double('Aws::S3::Object') }

      before { allow('Aws::S3::Object').to receive(:new).and_return(blob) }

      it 'should raise an error if the object is missing' do
        allow(s3).to receive(:get_object).
          and_raise(Aws::S3::Errors::NoSuchKey.new(nil, nil))

        expect {
          client.get('missing-oid')
        }.to raise_error(NotFound, /S3 object 'missing-oid' not found/)
      end

      it 'should get an object' do
        allow(s3).to receive(:get_object).and_yield('foooo')
        expect(client.get('foooo')).to eq('foooo')
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
        let(:client) { described_class.new(options) }

        it 'should get from folder' do
          allow(s3).to receive(:get_object).and_yield('foooo')

          # we want to return a body object
          expect(client.get('foooo')).to eq('foooo')
        end
      end
    end

    describe '#exists?' do
      let(:options) do
        {
          bucket_name: 'test',
          access_key_id: 'KEY',
          secret_access_key: 'SECRET'
        }
      end

      let(:blob) { instance_double('Aws::S3::Object') }
      let(:s3_client) { instance_double('Aws::S3::Client') }

      before do
        allow(Aws::S3::Object).to receive(:new).and_return(blob)
        allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
        allow(s3_client).to receive(:list_objects)
      end

      it 'should return true if the object already exists' do
        allow(blob).to receive(:exists?).and_return(true)
        expect(client.exists?('fake-oid')).to be(true)
      end

      it 'should return false if the object does not exist' do
        allow(blob).to receive(:exists?).and_return(false)
        expect(client.exists?('fake-oid')).to be(false)
      end

      it 'should only need to list objects once for the same client' do
        expect(Aws::S3::Client).to receive(:new).once.and_return(s3_client)
        expect(s3_client).to receive(:list_objects).once

        allow(blob).to receive(:exists?).and_return(true)
        expect(client.exists?('fake-oid')).to be(true)
        expect(client.exists?('fake-oid')).to be(true)
        expect(client.exists?('fake-oid')).to be(true)
        expect(client.exists?('fake-oid')).to be(true)
        expect(client.exists?('fake-oid')).to be(true)
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
      subject(:client) { described_class.new(options) }

      context 'without folder option' do
        let(:options) do
          {
            bucket_name: 'test',
            access_key_id: 'KEY',
            secret_access_key: 'SECRET'
          }
        end

        let(:blob) { instance_double('Aws::S3::Object') }

        before { allow(Aws::S3::Object).to receive(:new).and_return(blob) }
        it 'should delete an object' do
          allow(blob).to receive_messages(exists?: true)

          allow(blob).to receive(:delete)
          allow(s3).to receive(:delete_object)
          client.delete('fake-oid')
        end

        it 'should raise Bosh::Blobstore:NotFound error when the object is missing' do
          allow(blob).to receive_messages(exists?: false)

          expect {
            client.delete('fake-oid')
          }.to raise_error(NotFound, "Object 'fake-oid' is not found")
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

        let(:blob) { instance_double(Aws::S3::Object) }

        before { allow(Aws::S3::Object).to receive(:new).and_return(blob) }

        it 'should delete an object' do
          allow(blob).to receive_messages(exists?: true)

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

    describe 'credentials_source' do

      context 'when credentials_source is invalid' do
        before do
          options.merge!('credentials_source' => 'NotACredentialsSource')
        end

        it 'raises an error' do
          expect {
            client
          }.to raise_error(BlobstoreError, "invalid credentials_source")
        end
      end

      context 'when access_key_id and secret_access_key are provided with the env_or_profile credentials_source' do

        before do
          options.merge!(
          'credentials_source' => 'env_or_profile',
          'access_key_id' => 'KEY',
          'secret_access_key' => 'SECRET'
          )
        end

        it 'raises an error' do
          expect {
            client
          }.to raise_error(BlobstoreError, "can't use access_key_id or secret_access_key with env_or_profile credentials_source")
        end
      end
    end
  end
end
