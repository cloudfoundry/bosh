require 'spec_helper'

require 'bosh/dev/storage/fog_storage'

module Bosh::Dev::Storage
  describe FogStorage do
    include FakeFS::SpecHelpers

    let(:fog_storage) do
      Fog::Storage.new(
        provider: 'AWS',
        aws_access_key_id: 'fake access key',
        aws_secret_access_key: 'fake secret key'
      )
    end

    before do
      Fog.mock!
      Fog::Mock.reset
    end

    describe '#initialize' do
      before do
        ENV.stub(to_hash: {
          'AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT' => 'default fake access key',
          'AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT' => 'default fake secret key',
        })
      end

      context 'when passed a Fog::Storage object' do
        it 'uses the storages that is passed in' do
          storage = FogStorage.new(fog_storage)

          expect(storage.fog_storage).not_to be_nil
          expect(storage.fog_storage.instance_variable_get(:@aws_access_key_id)).to eq('fake access key')
          expect(storage.fog_storage.instance_variable_get(:@aws_secret_access_key)).to eq('fake secret key')
        end
      end

      context 'when passed no arguments' do
        it 'creates a Fog::Storage object from the environment variables' do
          storage = FogStorage.new

          expect(storage.fog_storage).not_to be_nil
          expect(storage.fog_storage.instance_variable_get(:@aws_access_key_id)).to eq('default fake access key')
          expect(storage.fog_storage.instance_variable_get(:@aws_secret_access_key)).to eq('default fake secret key')
        end
      end
    end

    describe '#download' do
      let(:bucket_name) { 'fake_bucket_name' }
      let(:remote_file_path) { '632/some/more' }
      let(:file_name) { 'path.yml' }
      let(:bucket_files) { fog_storage.directories.get(bucket_name).files }

      let(:storage) { FogStorage.new(fog_storage) }

      it 'downloads the file to the current directory' do
        fog_storage.directories.create(key: bucket_name) if bucket_name
        bucket_files.create(key: File.join(remote_file_path, file_name), body: 'hello world')

        expect {
          storage.download(bucket_name, remote_file_path, file_name)
        }.to change { Dir.glob('*') }.from([]).to([file_name])

        expect(File.read(file_name)).to eq('hello world')
      end

      it 'raises an error if the file does not exist' do
        fog_storage.directories.create(key: bucket_name) if bucket_name

        expect {
          storage.download(bucket_name, remote_file_path, file_name)
        }.to raise_error(%r{remote file '632/some/more/path.yml' not found})
      end

      it 'raises an error if the bucket does not exist' do
        expect {
          storage.download(bucket_name, remote_file_path, file_name)
        }.to raise_error("bucket 'fake_bucket_name' not found")
      end
    end

    describe '#upload' do
      let(:bucket_name) { 'fake_bucket_name' }
      let(:key) { 'fake_key.yml' }
      let(:body) { 'fake file body' }
      let(:public) { false }

      let(:storage) { FogStorage.new(fog_storage) }

      it 'uploads the file to remote path' do
        fog_storage.directories.create(key: bucket_name) if bucket_name

        storage.upload(bucket_name, key, body, public)
        expect(fog_storage.directories.get(bucket_name).files.get(key).body).to eq(body)
      end

      it 'raises an error if the bucket does not exist' do
        expect {
          storage.upload(bucket_name, key, body, public)
        }.to raise_error("bucket 'fake_bucket_name' not found")
      end
    end
  end
end