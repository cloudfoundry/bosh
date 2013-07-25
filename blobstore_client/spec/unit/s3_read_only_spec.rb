require 'spec_helper'

module Bosh::Blobstore
  describe S3BlobstoreClient do
    describe 'read only mode' do
      context 'without folder options' do
        let(:options) { { bucket_name: 'test' } }
        let(:client) { S3BlobstoreClient.new(options) }

        it 'should get objects' do
          client.should_receive(:get_file) do |id, file|
            id.should eq('foo')
            file.should be_instance_of File
          end

          client.get('foo')
        end

        it 'should pass through to simple.object_exists? for #exists?' do
          client.simple.should_receive(:exists?).with('foo')
          client.exists?('foo')
        end

        it 'should raise an error on create' do
          expect { client.create('foo') }.to raise_error BlobstoreError, 'unsupported action'
        end

        it 'should raise an error on delete' do
          expect { client.delete('foo') }.to raise_error BlobstoreError, 'unsupported action'
        end
      end

      context 'with folder options' do
        let(:options) { { bucket_name: 'test', folder: 'folder' } }
        let(:client) { S3BlobstoreClient.new(options) }

        it 'should pass through to simple.object_exists? for #exists? with folder' do
          client.simple.should_receive(:exists?).with('folder/foo')
          client.exists?('foo')
        end
      end
    end
  end
end
