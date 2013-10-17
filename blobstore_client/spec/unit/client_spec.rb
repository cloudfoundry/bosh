require 'spec_helper'

module Bosh::Blobstore
  describe Client do
    it 'should have a local provider' do
      Dir.mktmpdir do |tmp|
        Client.create('local', { blobstore_path: tmp }).should be_instance_of LocalClient
      end
    end

    it 'should have an simple provider' do
      Client.create('simple', {}).should be_instance_of SimpleBlobstoreClient
    end

    it 'should have an atmos provider' do
      Client.create('atmos', {}).should be_instance_of AtmosBlobstoreClient
    end

    it 'should have an s3 provider' do
      Client.create('s3', { access_key_id: 'foo', secret_access_key: 'bar' }).should be_instance_of S3BlobstoreClient
    end

    it 'should pick S3 provider when S3 is used without credentials' do
      Client.create('s3', { bucket_name: 'foo' }).should be_instance_of S3BlobstoreClient
    end

    it 'should have an swift provider' do
      Client.create('swift', {}).should be_instance_of SwiftBlobstoreClient
    end

    it 'should raise an exception on an unknown client' do
      expect { Client.create('foobar', {}) }.to raise_error /^Invalid client provider/
    end
  end
end