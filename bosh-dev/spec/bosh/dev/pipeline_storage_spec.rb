require 'spec_helper'

require 'bosh/dev/pipeline_storage'

module Bosh::Dev
  describe PipelineStorage do
    include FakeFS::SpecHelpers

    let(:storage) { PipelineStorage.new }

    before do
      Fog.mock!
      Fog::Mock.reset
      ENV.stub(to_hash: {
        'AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT' => 'default fake access key',
        'AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT' => 'default fake secret key',
      })
    end

    describe '#initialize' do
      it 'creates a Fog::Storage object from the environment variables' do
        expect(storage.fog_storage).not_to be_nil
        expect(storage.fog_storage.instance_variable_get(:@aws_access_key_id)).to eq('default fake access key')
        expect(storage.fog_storage.instance_variable_get(:@aws_secret_access_key)).to eq('default fake secret key')
      end
    end

    describe '#download' do
      let(:bucket_name) { 'fake-bucket-name' }
      let(:remote_file_path) { '632/some/more' }
      let(:file_name) { 'path.yml' }

      context 'when the file exists' do
        before do
          response = double('Net::HTTP::Response')
          response.should_receive(:read_body).and_yield('content')
          http = double('Net::HTTP')
          http.should_receive(:request_get).with('/632/some/more/path.yml').and_yield(response)
          Net::HTTP.stub(:start).with('fake-bucket-name.s3.amazonaws.com').and_yield(http)
        end

        it 'downloads the file to the current directory' do
          storage.download(bucket_name, remote_file_path, file_name)

          expect(File.read(file_name)).to eq('content')
        end
      end

      context 'when the file does not exist' do
        before do
          response = double('Net::HTTP::Response')
          response.should_receive(:kind_of?).and_return(Net::HTTPNotFound)
          http = double('Net::HTTP')
          http.should_receive(:request_get).with('/632/some/more/path.yml').and_yield(response)
          Net::HTTP.stub(:start).with('fake-bucket-name.s3.amazonaws.com').and_yield(http)
        end

        it 'raises an error if the file does not exist' do
          expect {
            storage.download(bucket_name, remote_file_path, file_name)
          }.to raise_error(%r{remote file '632/some/more/path.yml' not found})
        end
      end
    end

    describe '#upload' do
      let(:bucket_name) { 'fake_bucket_name' }
      let(:key) { 'fake_key.yml' }
      let(:body) { 'fake file body' }
      let(:public) { false }

      it 'uploads the file to remote path' do
        storage.fog_storage.directories.create(key: bucket_name) if bucket_name

        storage.upload(bucket_name, key, body, public)
        expect(storage.fog_storage.directories.get(bucket_name).files.get(key).body).to eq(body)
      end

      it 'raises an error if the bucket does not exist' do
        expect {
          storage.upload(bucket_name, key, body, public)
        }.to raise_error("bucket 'fake_bucket_name' not found")
      end
    end
  end
end