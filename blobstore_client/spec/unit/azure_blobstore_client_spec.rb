require 'spec_helper'

describe Bosh::Blobstore::AzureBlobstoreClient do

  def azure_test_blobstore(options)
    Bosh::Blobstore::AzureBlobstoreClient.new(options)
  end

  before(:each) do
    @azure = double(Azure::BlobService)
    Azure::BlobService.stub(:new).and_return(@azure)

    #@client = Bosh::Blobstore::AzureBlobstoreClient.new(options)
  end


  describe "options" do
    it "should raise and exception if storage_account_name is not provided" do
      options = {
          :storage_access_key => "base64++//==",
          :container_name => "test"
      }

      expect {
        azure_test_blobstore(options)
      }.to raise_error Bosh::Blobstore::BlobstoreError
    end

    it "should raise and exception if storage_account_name is not provided" do
      options = {
          :storage_access_key => "base64++//==",
          :storage_account_name => "test"
      }

      expect {
        azure_test_blobstore(options)
      }.to raise_error Bosh::Blobstore::BlobstoreError
    end
  end

  describe "#create_file" do
    let(:options){
      {
          "storage_account_name" => "asdfuhuru",
          "container_name" => "test",
          "storage_access_key" => "+uXSXBkPFvuE+E5mLTtfxiQ94iII/X7BtRs7vgX+dz638fmdw3/r2eadAiBpc7snjSCXknV+mkbTCus8+I97Zw=="
      }
    }
    let(:client){azure_test_blobstore(options)}

    it "should take a string as argument" do
      client.should_receive(:create_file) do |_, file|
        file.read().should == "barfoo"
      end

      client.create("barfoo")
    end

    it "should take a file as argument" do
      content = File.read(asset("file"))
      content_file = File.open(asset("file"))
      client.should_receive(:create_file) do |_, file|
        file.read().should == content
      end

      client.create(content_file)
    end

    it "should accept object id as suggestion" do
      client.should_receive(:create_file) do |id, file|
        id.should == 'id1'
      end

      client.create('content', 'id1')
    end

    it "should raise an error if the same object id is used" do
      client.should_receive(:object_exists?).and_return(true)

      expect {
        client.create('content', 'id1')
      }.to raise_error Bosh::Blobstore::BlobstoreError, "object id id1 is already in use"
    end
  end

  describe "#get_file" do
    let(:options){
      {
          "storage_account_name" => "asdfuhuru",
          "container_name" => "test",
          "storage_access_key" => "+uXSXBkPFvuE+E5mLTtfxiQ94iII/X7BtRs7vgX+dz638fmdw3/r2eadAiBpc7snjSCXknV+mkbTCus8+I97Zw=="
      }
    }
    let(:client){azure_test_blobstore(options)}

    it "should get an object" do
      @azure.stub(:get_blob_properties).with("test", "id1").and_return(double("blob", {:properties => {:content_length => 1}}))
      @azure.stub(:get_blob).and_return([double("blob"), "a"])

      client.get("id1").should eql("a")
    end

    it "should raise an error if object is missing" do
      @azure.stub(:get_blob_properties).with("test", "id1").and_raise(Azure::Core::Error)

      expect {
        client.get("id1")
      }.to raise_error(Bosh::Blobstore::BlobstoreError)
    end
  end

  describe "#object_exists?" do
    let(:options){
      {
          "storage_account_name" => "asdfuhuru",
          "container_name" => "test",
          "storage_access_key" => "+uXSXBkPFvuE+E5mLTtfxiQ94iII/X7BtRs7vgX+dz638fmdw3/r2eadAiBpc7snjSCXknV+mkbTCus8+I97Zw=="
      }
    }
    let(:client){azure_test_blobstore(options)}

    it "should return true if object exists" do
      @azure.should_receive(:get_blob_properties).with("test", "id1").and_return(double("blob"))

      client.exists?("id1").should be_true
    end

    it "should return false if object doesn't exists" do
      @azure.should_receive(:get_blob_properties).with("test", "id1").and_raise(Azure::Core::Error)

      client.exists?("id1").should be_false
    end
  end

  describe "#delete_object" do
    let(:options){
      {
          "storage_account_name" => "asdfuhuru",
          "container_name" => "test",
          "storage_access_key" => "+uXSXBkPFvuE+E5mLTtfxiQ94iII/X7BtRs7vgX+dz638fmdw3/r2eadAiBpc7snjSCXknV+mkbTCus8+I97Zw=="
      }
    }
    let(:client){azure_test_blobstore(options)}

    it "should delete an object" do
      @azure.should_receive(:delete_blob).with("test", "id1").and_return(nil)

      client.delete("id1")
    end

    it "should raise an exception if object id is not found" do
      @azure.should_receive(:delete_blob).with("test", "id1").and_raise(Azure::Core::Error)

      expect {
        client.delete("id1")
      }.to raise_error(Bosh::Blobstore::BlobstoreError)
    end
  end

end