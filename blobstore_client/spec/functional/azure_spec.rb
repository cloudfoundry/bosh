require 'spec_helper'

describe Bosh::Blobstore::AzureBlobstoreClient do
  def azure_storage_account_name
    v = ENV['STORAGE_ACCOUNT_NAME']
    raise "Missing STORAGE_ACCOUNT_NAME environment variable." unless v
    v
  end

  def azure_storage_access_key
    v = ENV['STORAGE_ACCESS_KEY']
    raise "Missing STORAGE_ACCESS_KEY environment variable." unless v
    v
  end

  def azure_storage_blob_host
    ENV['STORAGE_BLOB_HOST']
  end

  def container_name
    @container_name
    end

  before(:all) do
    Azure.config.storage_account_name = azure_storage_account_name
    Azure.config.storage_access_key = azure_storage_access_key

    @azure_blob_service = Azure::BlobService.new
    @container_name = "test-container-%08x" % rand(2**23)

    container = @azure_blob_service.create_container(@container_name, :public_access_level => "blob")
  end

  after (:all) do
    @azure_blob_service.delete_container(@container_name)
  end

  let (:content) { "foobar" }

  let(:azure_options) do
    {
        :storage_account_name => azure_storage_account_name,
        :container_name => @container_name,
        :storage_access_key => azure_storage_access_key,
        :storage_blob_host => azure_storage_blob_host
    }
  end

  let(:azure) do
    Bosh::Blobstore::Client.create("azure", azure_options)
  end

  after(:each) do
    azure.delete(@oid) if @oid
    azure.delete(@oid2) if @oid2
  end

  context "Private access" do


    describe "Store object" do
      it "should upload a string" do
        @oid = azure.create("foobar")
        @oid.should_not be_nil
      end

      it "should create a object with specified id" do
        @oid = azure.create("foobar", "obecjt-id-1")
        @oid.should eq "obecjt-id-1"
      end

      it "should upload a file" do
        Tempfile.new("bar") do |file|
          @oid = azure.create(file)
          @oid.should_not be_nil
        end
      end

      it "should handle uploading the same object twice" do
        @oid = azure.create("bar")
        @oid.should_not be_nil
        @oid2 = azure.create("foobar")
        @oid2.should_not be_nil
        @oid.should_not eq @oid2
      end
    end

    describe "Get object" do

      it "should save to a file" do
        @oid = azure.create(content)
        file = Tempfile.new("contents")
        azure.get(@oid, file)
        file.rewind
        file.read.should eq content
      end

      it "should return the contents" do
        @oid = azure.create(content)
        azure.get(@oid).should eq content
      end

      it "should raise an exception if the object id is invalid" do
        expect {
          azure.get("notpresent")
        }.to raise_error Bosh::Blobstore::BlobstoreError
      end

    end

    describe "Check object" do
      it "should check if the object exists" do
        @oid = azure.create(content)
        azure.exists?(@oid).should be_true
      end

      it "should check if the object does not exist" do
        azure.exists?("invliad-content-id").should be_false
      end
    end

    describe "Delete object" do
      it "should delete object" do
        @oid = azure.create(content)
        azure.delete(@oid)
        @oid = nil
      end

      it "should raise an exception if the object id is invalid" do
        expect {
          azure.delete("notpresent")
        }.to raise_error Bosh::Blobstore::BlobstoreError
      end

    end

    context "Big objects" do

      it "should upload and download a big file" do
        chunks = 1024 * 1024
        cfile = Tempfile.new("content_big")
        chunks.times do |i|
          cfile.write("x" * 10)
        end
        cfile.flush

        @oid = azure.create(File.new(cfile, "r"))

        lfile = Tempfile.new("downloaded_content")
        azure.get(@oid, File.new(lfile, "w"))
        lfile.flush

        lfile.rewind

        lfile.length.should == chunks * 10
        chunks.times do |i|
          lfile.read(10).should eq ("x" * 10)
        end

      end

    end


  end

  context "Public access" do

    let(:azure_options_public) do
      {
          :storage_account_name => azure_storage_account_name,
          :container_name => @container_name,
          :storage_blob_host => azure_storage_blob_host
      }
    end

    let(:azure_public) do
      Bosh::Blobstore::Client.create("azure", azure_options_public)
    end


    describe "Store object" do
      it "should raise an exception" do
        expect {
          @oid = azure_public.create("foobar", "obecjt-id-1")
        }.to raise_error Bosh::Blobstore::BlobstoreError
      end
    end

    describe "Get object" do

      it "should save to a file" do
        @oid = azure.create(content)
        file = Tempfile.new("contents")
        azure_public.get(@oid, file)
        file.rewind
        file.read.should eq content
      end

      it "should return the contents" do
        @oid = azure.create(content)
        azure_public.get(@oid).should eq content
      end

      it "should raise an exception if the object id is invalid" do
        expect {
          azure_public.get("notpresent")
        }.to raise_error Bosh::Blobstore::BlobstoreError
      end

    end

    describe "Check object" do
      it "should check if the object exists" do
        @oid = azure.create(content)
        azure_public.exists?(@oid).should be_true
      end

      it "should check if the object does not exist" do
        azure_public.exists?("invliad-content-id").should be_false
      end
    end

    describe "Delete object" do
      it "should raise an exception" do
        @oid = azure.create(content)
        expect {
          azure_public.delete(@oid)
        }.to raise_error Bosh::Blobstore::BlobstoreError
      end

    end

  end

end
