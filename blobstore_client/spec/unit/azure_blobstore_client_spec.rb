require 'spec_helper'

module Bosh::Blobstore
  describe AzureBlobstoreClient do
    subject(:client) { AzureBlobstoreClient.new({ :storage_account_name => "aStorageAccountName", :storage_access_key => "1234567890", :container_name => "aContainer" }) }

    before(:each) do
      @mock_blob_client = double("blob client")
      allow(Azure::BlobService).to receive(:new).and_return(@mock_blob_client)
      allow(@mock_blob_client).to receive(:get_container_properties)
    end
    
    describe "#initialize" do

      it "should initialize the Azure config with the appropriate parameters" do
        mock_config = double("azure config")
        
        expect(mock_config).to receive(:storage_account_name=).with("aStorageAccountName")
        expect(mock_config).to receive(:storage_access_key=).with("1234567890")
        expect(Azure).to receive(:configure).and_yield(mock_config)
        
        client
      end
      
      it "should make use the specified container_name exists" do
        expect(@mock_blob_client).to receive(:get_container_properties).with("aContainer")
        
        client
      end
      
      it "should create the container if it doesn't exist" do
        allow(@mock_blob_client).to receive(:get_container_properties).and_raise(Azure::Core::Error)
        
        expect(@mock_blob_client).to receive(:create_container).with("aContainer")
        
        client
      end
      
      it "should handle a failure creating the blobstore client and raise a BlobstoreError instead" do
        allow(Azure::BlobService).to receive(:new).and_raise(Azure::Core::Error)
        
        expect{client}.to raise_error(BlobstoreError, /Failed to initialize Azure blobstore:/)
      end
    end
    
    describe "#create_file" do
      
      before(:each) do
        allow(@mock_blob_client).to receive(:get_blob_properties).and_raise(Azure::Core::Error)
        @mock_file = double("file")
        @mock_file_content = "someContent"
        allow(@mock_file).to receive(:read).and_return(@mock_file_content)
        allow(@mock_blob_client).to receive(:create_block_blob)
      end
      
      it "should generate and id if none is provided" do
        result = client.create_file(nil, @mock_file)
        
        expect(result).to_not be(nil)
      end
      
      it "should raise a BlobstoreError if the specified id already exists" do
        id = "1234"
        allow(@mock_blob_client).to receive(:get_blob_properties)
        
        expect{ client.create_file(id, @mock_file) }.to raise_error(BlobstoreError, /object id #{id} is already in use/)
      end
      
      it "should upload the content to the given id" do
        id = "1234"
        expect(@mock_blob_client).to receive(:create_block_blob).with("aContainer", id, @mock_file_content)

        client.create_file(id, @mock_file)
      end
      
      it "should raise a BlobstoreError if the upload fails" do
        expect(@mock_blob_client).to receive(:create_block_blob).and_raise(Azure::Core::Error)

        expect{ client.create_file(nil, @mock_file) }.to raise_error(BlobstoreError, /Failed to create object, Azure response error:/)
      end
    end
    
    describe "#get_file" do
      
      before(:each) do
        @mock_content = "blob content"
        @mock_file = double("file")
        allow(@mock_blob_client).to receive(:get_blob).and_return(nil, @mock_content)
        allow(@mock_file).to receive(:write)
      end
      
      it "should fetch the data from the given id" do
        id = "1234"
        
        expect(@mock_blob_client).to receive(:get_blob).with("aContainer", id).and_return(nil, @mock_content).once
        
        client.get_file(id, @mock_file)
      end
      
      it "should write the data to the given file" do
        expect(@mock_file).to receive(:write)

        client.get_file("", @mock_file)
      end
      
      it "should raise a BlobstoreError if the fetch fails" do
        id = "1234"
        
        allow(@mock_blob_client).to receive(:get_blob).and_raise(Azure::Core::Error)
        
        expect{ client.get_file(id, @mock_file) }.to raise_error(BlobstoreError, /Failed to find object '#{id}', Azure response error:/)
      end
    end
    
    describe "#delete_object" do
      
      before(:each) do
        allow(@mock_blob_client).to receive(:delete_blob)
      end
      
      it "should delete the given blob id" do
        id = "1234"
        
        expect(@mock_blob_client).to receive(:delete_blob).with("aContainer", id)
        
        client.delete_object(id)
      end
      
      it "should raise a blobstore error if the given blob doesnt exist" do
        id = "1234"
        
        allow(@mock_blob_client).to receive(:delete_blob).and_raise(Azure::Core::Error)
        
        expect{client.delete_object(id)}.to raise_error(BlobstoreError, /Failed to delete object '#{id}', Azure response error:/)
      end
    end
  end
end
    