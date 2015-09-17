require 'spec_helper'

module Bosh::Blobstore
  describe SwiftBlobstoreClient do

    def swift_options(container_name, swift_provider, credentials)
      if credentials
        options = {
          'hp' => {
            'hp_access_key' => 'access_key',
            'hp_secret_key' => 'secret_key',
            'hp_tenant_id' => 'tenant_id',
            'hp_avl_zone' => 'region'
          },
          'openstack' => {
            'openstack_auth_url' => 'auth_url',
            'openstack_username' => 'username',
            'openstack_api_key' => 'api_key',
            'openstack_tenant' => 'tenant',
            'openstack_region' => 'region'
          },
          'rackspace' => {
            'rackspace_username' => 'username',
            'rackspace_api_key' => 'api_key',
            'rackspace_region' => 'region'
          }
        }
      else
        options = {}
      end
      options['container_name'] = container_name if container_name
      options['swift_provider'] = swift_provider if swift_provider
      options
    end

    def swift_blobstore(options)
      SwiftBlobstoreClient.new(options)
    end

    before(:each) do
      @swift = double('swift')
      allow(Fog::Storage).to receive(:new).and_return(@swift)
      @http_client = double('http-client')
      allow(HTTPClient).to receive(:new).and_return(@http_client)
    end

    describe 'interface' do
      subject { SwiftBlobstoreClient.new(options) }
      let(:options) { swift_options('test-container', 'hp', true) }
      it_implements_base_client_interface
    end

    describe 'on HP Cloud Storage' do
      let(:data) { 'some content' }
      let(:directories) { double('directories') }
      let(:container) { double('container') }
      let(:files) { double('files') }
      let(:object) { double('object') }

      describe 'with credentials' do
        before(:each) do
          @client = swift_blobstore(swift_options('test-container', 'hp', true))
        end

        describe '#create_file' do
          it 'should create an object' do
            expect(@client).to receive(:generate_object_id).and_return('object_id')
            allow(@swift).to receive(:directories).and_return(directories)
            expect(directories).to receive(:get).with('test-container').and_return(container)
            expect(container).to receive(:files).and_return(files)
            expect(files).to receive(:create) do |opt|
              expect(opt[:key]).to eq 'object_id'
              object
            end
            expect(object).to receive(:public_url).and_return('public-url')

            object_id = @client.create(data)
            object_info = MultiJson.decode(Base64.decode64(URI.unescape(object_id)))
            expect(object_info['oid']).to eq('object_id')
            expect(object_info['purl']).to eq('public-url')
          end
        end

        describe '#get_file' do
          it 'should fetch an object without a public url' do
            allow(@swift).to receive(:directories).and_return(directories)
            expect(directories).to receive(:get).with('test-container').and_return(container)
            expect(container).to receive(:files).and_return(files)
            expect(files).to receive(:get).with('object_id').and_yield(data).and_return(object)

            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))
            expect(@client.get(oid)).to eq(data)
          end

          it 'should fetch an object with a public url' do
            response = double('response')

            expect(@http_client).to receive(:get).with('public-url').and_yield(data).and_return(response)
            allow(response).to receive(:status).and_return(200)

            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id', purl: 'public-url' })))
            expect(@client.get(oid)).to eq(data)
          end
        end

        describe '#delete_object' do
          it 'should delete an object' do
            allow(@swift).to receive(:directories).and_return(directories)
            expect(directories).to receive(:get).with('test-container').and_return(container)
            expect(container).to receive(:files).and_return(files)
            expect(files).to receive(:get).with('object_id').and_return(object)
            expect(object).to receive(:destroy)

            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))
            @client.delete(oid)
          end

          it 'should raise Bosh::Blobstore::NotFound error when the file is not found in swift during deleting' do
            allow(@swift).to receive(:directories).and_return(directories)
            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))

            expect(directories).to receive(:get).with('test-container').and_return(container)
            expect(container).to receive(:files).and_return(files)
            expect(files).to receive(:get).with('object_id').and_return(nil)

            expect{
              @client.delete(oid)
            }.to raise_error NotFound, /Swift object '#{oid}' not found/
          end

          it 'should raise BlobstoreError error when failed to delete the object' do
            allow(@swift).to receive(:directories).and_return(directories)
            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))

            expect(directories).to receive(:get).with('test-container').and_return(container)
            expect(container).to receive(:files).and_return(files)
            expect(files).to receive(:get).with('object_id').and_return(object)
            expect(object).to receive(:destroy).and_raise BlobstoreError

            expect{
              @client.delete(oid)
            }.to raise_error BlobstoreError, /Failed to delete object '#{oid}':/
          end
        end

        describe '#object_exists?' do
          it 'should return true if object exists' do
            allow(@swift).to receive(:directories).and_return(directories)
            expect(directories).to receive(:get).with('test-container').and_return(container)
            expect(container).to receive(:files).and_return(files)
            expect(files).to receive(:head).with('object_id').and_return(object)

            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))
            expect(@client.exists?(oid)).to be(true)
          end

          it "should return false if object doesn't exists" do
            allow(@swift).to receive(:directories).and_return(directories)
            expect(directories).to receive(:get).with('test-container').and_return(container)
            expect(container).to receive(:files).and_return(files)
            expect(files).to receive(:head).with('object_id').and_return(nil)

            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))
            expect(@client.exists?(oid)).to be(false)
          end
        end
      end

      describe 'without credentials' do
        before(:each) do
          @client = swift_blobstore(swift_options('test-container', 'hp', false))
        end

        describe '#create_file' do
          it 'should refuse to create an object' do
            expect { @client.create(data) }.to raise_error(BlobstoreError)
          end
        end

        describe '#get_file' do
          it 'should refuse to fetch an object without a public url' do
            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))

            expect { @client.get(oid) }.to raise_error(BlobstoreError)
          end

          it 'should fetch an object with a public url' do
            response = double('response')

            expect(@http_client).to receive(:get).with('public-url').and_yield(data).and_return(response)
            allow(response).to receive(:status).and_return(200)

            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id', purl: 'public-url' })))
            expect(@client.get(oid)).to eq(data)
          end
        end

        describe '#delete_object' do
          it 'should refuse to delete an object' do
            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))

            expect { @client.delete(oid) }.to raise_error(BlobstoreError)
          end
        end

        describe '#object_exists?' do
          it 'should raise a BlobstoreError exception' do
            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))

            expect { @client.exists?(oid).should be(true) }.to raise_error(BlobstoreError)
          end
        end
      end
    end

    describe 'on OpenStack Cloud Storage' do
      let(:data) { 'some content' }
      let(:directories) { double('directories') }
      let(:container) { double('container') }
      let(:files) { double('files') }
      let(:object) { double('object') }

      describe 'with credentials' do
        before(:each) do
          @client = swift_blobstore(swift_options('test-container', 'openstack', true))
        end

        describe '#create_file' do
          it 'should create an object' do
            expect(@client).to receive(:generate_object_id).and_return('object_id')
            allow(@swift).to receive(:directories).and_return(directories)
            expect(directories).to receive(:get).with('test-container').and_return(container)
            expect(container).to receive(:files).and_return(files)
            expect(files).to receive(:create) do |opt|
              expect(opt[:key]).to eq('object_id')
              object
            end
            expect(object).to receive(:public_url).and_raise(NotImplementedError)

            object_id = @client.create(data)
            object_info = MultiJson.decode(Base64.decode64(URI.unescape(object_id)))
            expect(object_info['oid']).to eq('object_id')
            expect(object_info['purl']).to be(nil)
          end
        end

        describe '#get_file' do
          it 'should fetch an object without a public url' do
            allow(@swift).to receive(:directories).and_return(directories)
            expect(directories).to receive(:get).with('test-container').and_return(container)
            expect(container).to receive(:files).and_return(files)
            expect(files).to receive(:get).with('object_id').and_yield(data).and_return(object)

            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))
            expect(@client.get(oid)).to eql(data)
          end

          it 'should fetch an object with a public url' do
            response = double('response')

            expect(@http_client).to receive(:get).with('public-url').and_yield(data).and_return(response)
            allow(response).to receive(:status).and_return(200)

            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id', purl: 'public-url' })))
            expect(@client.get(oid)).to eql(data)
          end
        end

        describe '#delete_object' do
          it 'should delete an object' do
            allow(@swift).to receive(:directories).and_return(directories)
            expect(directories).to receive(:get).with('test-container').and_return(container)
            expect(container).to receive(:files).and_return(files)
            expect(files).to receive(:get).with('object_id').and_return(object)
            expect(object).to receive(:destroy)

            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))
            @client.delete(oid)
          end

          it 'should raise Bosh::Blobstore::NotFound error when the file is not found in swift during deleting' do
            allow(@swift).to receive(:directories).and_return(directories)
            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))

            expect(directories).to receive(:get).with('test-container').and_return(container)
            expect(container).to receive(:files).and_return(files)
            expect(files).to receive(:get).with('object_id').and_return(nil)

            expect{
              @client.delete(oid)
            }.to raise_error NotFound, /Swift object '#{oid}' not found/
          end

          it 'should raise BlobstoreError error when failed to delete the object' do
            allow(@swift).to receive(:directories).and_return(directories)
            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))

            expect(directories).to receive(:get).with('test-container').and_return(container)
            expect(container).to receive(:files).and_return(files)
            expect(files).to receive(:get).with('object_id').and_return(object)
            expect(object).to receive(:destroy).and_raise BlobstoreError

            expect{
              @client.delete(oid)
            }.to raise_error BlobstoreError, /Failed to delete object '#{oid}':/
          end
        end

        describe '#object_exists?' do
          it 'should return true if object exists' do
            allow(@swift).to receive(:directories).and_return(directories)
            expect(directories).to receive(:get).with('test-container').and_return(container)
            expect(container).to receive(:files).and_return(files)
            expect(files).to receive(:head).with('object_id').and_return(object)

            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))
            expect(@client.exists?(oid)).to be(true)
          end

          it "should return false if object doesn't exists" do
            allow(@swift).to receive(:directories).and_return(directories)
           expect(directories).to receive(:get).with('test-container').and_return(container)
           expect(container).to receive(:files).and_return(files)
           expect(files).to receive(:head).with('object_id').and_return(nil)

            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))
            expect(@client.exists?(oid)).to be(false)
          end
        end
      end

      describe 'without credentials' do
        before(:each) do
          @client = swift_blobstore(swift_options('test-container', 'openstack', false))
        end

        describe '#create_file' do
          it 'should refuse to create an object' do
            expect { @client.create(data) }.to raise_error(BlobstoreError)
          end
        end

        describe '#get_file' do
          it 'should refuse to fetch an object without a public url' do
            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))

            expect { @client.get(oid) }.to raise_error(BlobstoreError)
          end

          it 'should fetch an object with a public url' do
            response = double('response')

            expect(@http_client).to receive(:get).with('public-url').and_yield(data).and_return(response)
            allow(response).to receive(:status).and_return(200)

            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id', purl: 'public-url' })))
            expect(@client.get(oid)).to eq(data)
          end
        end

        describe '#delete_object' do
          it 'should refuse to delete an object' do
            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))

            expect { @client.delete(oid) }.to raise_error(BlobstoreError)
          end
        end

        describe '#object_exists?' do
          it 'should raise a BlobstoreError exception' do
            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))

            expect { @client.exists?(oid).should be(true) }.to raise_error(BlobstoreError)
          end
        end
      end
    end

    describe 'on Rackspace Cloud Files' do
      let(:data) { 'some content' }
      let(:directories) { double('directories') }
      let(:container) { double('container') }
      let(:files) { double('files') }
      let(:object) { double('object') }

      describe 'with credentials' do
        before(:each) do
          @client = swift_blobstore(swift_options('test-container', 'rackspace', true))
        end

        describe '#create_file' do
          it 'should create an object' do
            expect(@client).to receive(:generate_object_id).and_return('object_id')
            allow(@swift).to receive(:directories).and_return(directories)
            expect(directories).to receive(:get).with('test-container').and_return(container)
            expect(container).to receive(:files).and_return(files)
            expect(files).to receive(:create) do |opt|
              expect(opt[:key]).to eq 'object_id'
              object
            end
            expect(object).to receive(:public_url).and_return('public-url')

            object_id = @client.create(data)
            object_info = MultiJson.decode(Base64.decode64(URI.unescape(object_id)))
            expect(object_info['oid']).to eq('object_id')
            expect(object_info['purl']).to eq('public-url')
          end
        end

        describe '#get_file' do
          it 'should fetch an object without a public url' do
            allow(@swift).to receive(:directories).and_return(directories)
            expect(directories).to receive(:get).with('test-container').and_return(container)
            expect(container).to receive(:files).and_return(files)
            expect(files).to receive(:get).with('object_id').and_yield(data).and_return(object)

            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))
            expect(@client.get(oid)).to eq(data)
          end

          it 'should fetch an object with a public url' do
            response = double('response')

            expect(@http_client).to receive(:get).with('public-url').and_yield(data).and_return(response)
            allow(response).to receive(:status).and_return(200)

            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id', purl: 'public-url' })))
            expect(@client.get(oid)).to eq(data)
          end
        end

        describe '#delete_object' do
          it 'should delete an object' do
            allow(@swift).to receive(:directories).and_return(directories)
            expect(directories).to receive(:get).with('test-container').and_return(container)
            expect(container).to receive(:files).and_return(files)
            expect(files).to receive(:get).with('object_id').and_return(object)
            expect(object).to receive(:destroy)

            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))
            @client.delete(oid)
          end

          it 'should raise Bosh::Blobstore::NotFound error when the file is not found in swift during deleting' do
            allow(@swift).to receive(:directories).and_return(directories)
            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))

            expect(directories).to receive(:get).with('test-container').and_return(container)
            expect(container).to receive(:files).and_return(files)
            expect(files).to receive(:get).with('object_id').and_return(nil)

            expect{
              @client.delete(oid)
            }.to raise_error NotFound, /Swift object '#{oid}' not found/
          end

          it 'should raise BlobstoreError error when failed to delete the object' do
            allow(@swift).to receive(:directories).and_return(directories)
            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))

            expect(directories).to receive(:get).with('test-container').and_return(container)
            expect(container).to receive(:files).and_return(files)
            expect(files).to receive(:get).with('object_id').and_return(object)
            expect(object).to receive(:destroy).and_raise BlobstoreError

            expect{
              @client.delete(oid)
            }.to raise_error BlobstoreError, /Failed to delete object '#{oid}':/
          end
        end

        describe '#object_exists?' do
          it 'should return true if object exists' do
            allow(@swift).to receive(:directories).and_return(directories)
            expect(directories).to receive(:get).with('test-container').and_return(container)
            expect(container).to receive(:files).and_return(files)
            expect(files).to receive(:head).with('object_id').and_return(object)

            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))
            expect(@client.exists?(oid)).to be(true)
          end

          it "should return false if object doesn't exists" do
            allow(@swift).to receive(:directories).and_return(directories)
            expect(directories).to receive(:get).with('test-container').and_return(container)
            expect(container).to receive(:files).and_return(files)
            expect(files).to receive(:head).with('object_id').and_return(nil)

            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))
            expect(@client.exists?(oid)).to be(false)
          end
        end
      end

      describe 'without credentials' do
        before(:each) do
          @client = swift_blobstore(swift_options('test-container', 'rackspace', false))
        end

        describe '#create_file' do
          it 'should refuse to create an object' do
            expect { @client.create(data) }.to raise_error(BlobstoreError)
          end
        end

        describe '#get_file' do
          it 'should refuse to fetch an object without a public url' do
            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))

            expect { @client.get(oid) }.to raise_error(BlobstoreError)
          end

          it 'should fetch an object with a public url' do
            response = double('response')

            expect(@http_client).to receive(:get).with('public-url').and_yield(data).and_return(response)
            allow(response).to receive(:status).and_return(200)

            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id', purl: 'public-url' })))
            expect(@client.get(oid)).to eq(data)
          end
        end

        describe '#delete_object' do
          it 'should refuse to delete an object' do
            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))

            expect { @client.delete(oid) }.to raise_error(BlobstoreError)
          end
        end

        describe '#object_exists?' do
          it 'should raise a BlobstoreError exception' do
            oid = URI.escape(Base64.encode64(MultiJson.encode({ oid: 'object_id' })))

            expect { @client.exists?(oid).should be(true) }.to raise_error(BlobstoreError)
          end
        end
      end
    end
  end
end
