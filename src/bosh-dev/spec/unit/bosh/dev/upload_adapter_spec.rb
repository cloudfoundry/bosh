require 'spec_helper'
require 'bosh/dev/upload_adapter'

module Bosh::Dev
  describe UploadAdapter do
    let(:adapter) { UploadAdapter.new }

    let(:aws_access_key_id) { 'default fake access key' }
    let(:aws_secret_access_key) { 'default fake secret key' }

    let(:fog_storage) { Fog::Storage.new(
      provider: 'AWS',
      aws_access_key_id: aws_access_key_id,
      aws_secret_access_key: aws_secret_access_key)
    }

    before do
      Fog.mock!
      Fog::Mock.reset
      allow(ENV).to receive_messages(to_hash: {
        'BOSH_AWS_ACCESS_KEY_ID' => aws_access_key_id,
        'BOSH_AWS_SECRET_ACCESS_KEY' => aws_secret_access_key,
      })
    end

    describe '#upload' do
      let(:bucket_name) { 'fake_bucket_name' }
      let(:key) { 'fake_key.yml' }
      let(:body) { 'fake file body' }
      let(:public) { false }

      context 'when body is an IO' do
        let(:body) { StringIO.new('body') }

        it 'uploads the file to remote path' do
          fog_storage.directories.create(key: bucket_name)

          adapter.upload(bucket_name: bucket_name, key: key, body: body, public: public)

          expect(fog_storage.directories.get(bucket_name).files.get(key).body).to eq('body')
        end
      end

      context 'when body is a string' do
        it 'uploads the file to remote path' do
          fog_storage.directories.create(key: bucket_name)

          adapter.upload(bucket_name: bucket_name, key: key, body: body, public: public)

          expect(fog_storage.directories.get(bucket_name).files.get(key).body).to eq(body)
        end

        it 'returns the created file object, used by the stemcell:upload_os_image Rake task' do
          fog_storage.directories.create(key: bucket_name)
          result = adapter.upload(bucket_name: bucket_name, key: key, body: body, public: public)
          expect(result).to be_a(Fog::Storage::AWS::File)
        end
      end

      it 'raises an error if the bucket does not exist' do
        expect {
          adapter.upload(bucket_name: bucket_name, key: key, body: body, public: public)
        }.to raise_error("bucket 'fake_bucket_name' not found")
      end

    end
  end
end
