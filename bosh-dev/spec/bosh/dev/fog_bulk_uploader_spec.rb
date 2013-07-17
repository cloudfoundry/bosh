require 'spec_helper'
require 'bosh/dev/fog_bulk_uploader'
require 'fakefs/spec_helpers'

describe Bosh::Dev::FogBulkUploader do
  include FakeFS::SpecHelpers

  let(:bucket_name) { 'bosh-ci-pipeline' }
  let(:pipeline) { double(Bosh::Dev::Pipeline, bucket: bucket_name, fog_storage: fog_storage) }
  let(:src) { 'source_dir' }
  let(:dst) { 'dest_dir' }
  let(:fake_logger) { double('Logger', info: true) }

  let(:fog_storage) do
    Fog::Storage.new(provider: 'AWS',
                     aws_access_key_id: 'access key',
                     aws_secret_access_key: 'secret key')
  end

  let(:files) do
    %w[
      test_file
      foo/bar.txt
      foo/bar.rb
      foo/bar/baz.txt
    ]
  end

  subject { Bosh::Dev::FogBulkUploader.new(pipeline) }

  before do
    Fog.mock!

    fog_storage.directories.create(key: bucket_name)
    FileUtils.mkdir_p(src)

    Dir.chdir(src) do
      files.each do |file|
        FileUtils.mkdir_p(File.dirname(file))
        File.open(file, 'w') { |f| f.write(file) }
      end
    end
    Logger.stub(:new).and_return(fake_logger)

    ENV.stub(:to_hash).and_return({
                                      'AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT' => 'access key',
                                      'AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT' => 'secret key'
                                  })
  end

  context 'with a real pipeline' do
    subject(:uploader) do
      Bosh::Dev::FogBulkUploader.new
    end

    it 'creates a new uploader for the aws pipeline from environment variables' do
      expect(uploader.base_dir).to eq(pipeline.bucket)
    end

    describe '#fog_storage' do
      before do
        ENV.stub(:to_hash).and_return({
                                          'AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT' => 'fake access key',
                                          'AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT' => 'fake secret key',
                                      })
      end

      it 'uses the aws access key and secret key configured in Jenkins' do
        expect(uploader.fog_storage).not_to be_nil
        expect(uploader.fog_storage.instance_variable_get(:@aws_access_key_id)).to eq('fake access key')
        expect(uploader.fog_storage.instance_variable_get(:@aws_secret_access_key)).to eq('fake secret key')
      end
    end
  end

  describe '#base_directory' do
    it 'raises an error when base_directory is not found in provider' do
      pipeline.stub(bucket: 'foo')
      expect {
        subject.base_directory
      }.to raise_error("bucket 'foo' not found")
    end
  end

  describe 'upload_r' do
    let(:bucket) { fog_storage.directories.get(bucket_name) }

    it 'recursively uploads a directory into base_dir' do
      subject.upload_r(src, dst)
      expect(bucket).to_not be_nil
      expect(bucket.files.head('dest_dir/test_file')).to_not be_nil
      expect(bucket.files.head('dest_dir/foo/bar.txt')).to_not be_nil
      expect(bucket.files.head('dest_dir/foo/bar/baz.txt')).to_not be_nil
    end

    it 'correctly uploads the contents of the files' do
      subject.upload_r(src, dst)
      expect(bucket.files.get('dest_dir/test_file').body).to eq('test_file')
      expect(bucket.files.get('dest_dir/foo/bar/baz.txt').body).to eq('foo/bar/baz.txt')
    end

    it 'logs that it has uploaded each file' do
      fake_logger.should_receive(:info).with("uploaded foo/bar.rb to https://#{bucket_name}.s3.amazonaws.com/dest_dir/foo/bar.rb")
      subject.upload_r(src, dst)
    end
  end
end
