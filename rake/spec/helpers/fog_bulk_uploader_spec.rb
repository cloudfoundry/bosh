require 'spec_helper'
require 'helpers/fog_bulk_uploader'
require 'fakefs/spec_helpers'

describe Bosh::Helpers::FogBulkUploader do
  include FakeFS::SpecHelpers

  let(:fog_options) do
    {
        provider:              'AWS',
        aws_access_key_id:     'access key',
        aws_secret_access_key: 'secret key'
    }
  end
  let(:fog_storage) { Fog::Storage.new(fog_options) }
  let(:base_dir) { 'base-dir' }

  subject { Bosh::Helpers::FogBulkUploader.new(base_dir, fog_options) }

  let(:src) { 'source_dir' }
  let(:dst) { 'dest_dir' }
  let(:fake_logger) { double('Logger', info: true)}
  let(:files) {
    %w[
      test_file
      foo/bar.txt
      foo/bar.rb
      foo/bar/baz.txt
    ]
  }

  before do
    Fog.mock!

    fog_storage.directories.create(key: base_dir )
    FileUtils.mkdir_p(src)

    Dir.chdir(src) do
      files.each do |file|
        FileUtils.mkdir_p(File.dirname(file))
        File.open(file, 'w') { |f| f.write(file) }
      end
    end
    Logger.stub(:new).and_return(fake_logger)
  end

  it 'raises an error when base_directory is not found in provider' do
    uploader = Bosh::Helpers::FogBulkUploader.new('foo', fog_options)
    expect {
      uploader.base_directory
    }.to raise_error("bucket 'foo' not found")
  end

  describe 'aws_pipeline' do
    it 'creates a new uploader for the aws pipeline from environment variables' do
      ENV.should_receive(:fetch).with('AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT').and_return('access key')
      ENV.should_receive(:fetch).with('AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT').and_return('secret key')
      ENV.should_receive(:fetch).with('BOSH_CI_PIPELINE_BUCKET', anything).and_call_original
      uploader = Bosh::Helpers::FogBulkUploader.s3_pipeline
      expect(uploader.base_dir).to eq('bosh-ci-pipeline')
    end
  end

  describe 'upload_r' do
    let(:bucket) { fog_storage.directories.get('base-dir') }

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
      fake_logger.should_receive(:info).with('uploaded foo/bar.rb to https://base-dir.s3.amazonaws.com/dest_dir/foo/bar.rb')
      subject.upload_r(src, dst)
    end
  end
end