require 'spec_helper'

describe Bosh::Blobstore::S3BlobstoreClient do
  let(:options) { {:bucket_name => 'test'} }
  let(:client) { Bosh::Blobstore::S3BlobstoreClient.new(options) }

  describe 'read only mode' do
    it 'should get objects' do
      client.should_receive(:get_file) do |id, file|
        id.should == 'foo'
        file.should be_instance_of File
      end
      client.get('foo')
    end

    it 'should pass through to simple.object_exists? for #exists?' do
      client.simple.should_receive(:exists?).with('foo')
      client.exists?('foo')
    end

    it 'should raise an error on create' do
      expect {
        client.create('foo')
      }.to raise_error Bosh::Blobstore::BlobstoreError, 'unsupported action'
    end

    it 'should raise an error on delete' do
      expect {
        client.delete('foo')
      }.to raise_error Bosh::Blobstore::BlobstoreError, 'unsupported action'
    end
  end
end
