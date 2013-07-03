require 'spec_helper'
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', 'cassettes'))
  c.hook_into :webmock
  c.configure_rspec_metadata!
end


describe Bosh::Blobstore::AzureBlobstoreClient do
  def azure_storage_account_name
    v = ENV['STORAGE_ACCOUNT_NAME'] || "asdfuhuru"
  end

  def azure_storage_access_key
    v = ENV['STORAGE_ACCESS_KEY'] || "5lb+5ZXxyN5zEcSGFUrVhTeBJYhKx2UwxbhmeFv+6usmNuxq0Tj0IgvIQEqcSJ0roHllg4xOQF+9ZMehldiznA=="
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
    @container_name = "test-container"

    VCR.use_cassette('Create container') do
      container = @azure_blob_service.create_container(@container_name, :public_access_level => "blob")
    end
  end

  after (:all) do
    VCR.use_cassette('Delete container') do
      @azure_blob_service.delete_container(@container_name)
    end
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
    if @oid
      VCR.use_cassette("Delete object #{@oid}") do
        azure.delete(@oid)
      end
    end

    if @oid2
      VCR.use_cassette("Delete object #{@oid2}") do
        azure.delete(@oid2)
      end
    end
  end

  context "Private access" do

    describe "Store object" do
      it "should upload a string", :vcr => true do
        azure.should_receive(:generate_object_id).and_return("id1")
        @oid = azure.create("foobar")
        @oid.should_not be_nil
      end

      it "should create an object with specified id", :vcr => true do
        @oid = azure.create("foobar", "object-id-1")
        @oid.should eq "object-id-1"
      end

      it "should upload a file", :vcr => true  do
        Tempfile.new("bar") do |file|
          azure.should_receive(:generate_object_id).and_return("id2")
          @oid = azure.create(file)
          @oid.should_not be_nil
        end
      end

      it "should handle uploading the same object twice", :vcr => true do
        @oid = azure.create("bar", "id3")
        @oid.should_not be_nil

        @oid2 = azure.create("foobar", "id4")
        @oid2.should_not be_nil
        @oid.should_not eq @oid2
      end
    end

    describe "Get object" do

      it "should save to a file", :vcr => true do
        @oid = azure.create(content, "id5")
        file = Tempfile.new("contents")
        azure.get(@oid, file)
        file.rewind
        file.read.should eq content
      end

      it "should return the contents", :vcr => true do
        azure.should_receive(:generate_object_id).and_return("id6")
        @oid = azure.create(content)
        azure.get(@oid).should eq content
      end

      it "should raise an exception if the object id is invalid", :vcr => true do
        expect {
          azure.get("notpresent")
        }.to raise_error Bosh::Blobstore::BlobstoreError
      end

    end

    describe "Check object" do
      it "should check if the object exists", :vcr => true do
        @oid = azure.create(content, "id7")
        azure.exists?(@oid).should be_true
      end

      it "should check if the object does not exist", :vcr => true do
        azure.exists?("invliad-content-id").should be_false
      end
    end

    describe "Delete object" do
      it "should delete object", :vcr => true do
        @oid = azure.create(content, "id8")
        azure.delete(@oid)
        @oid = nil
      end

      it "should raise an exception if the object id is invalid", :vcr => true do
        expect {
          azure.delete("notpresent")
        }.to raise_error Bosh::Blobstore::BlobstoreError
      end

    end

    context "Big objects" do

      # To big to be used with VCR  # 10 MiB
      xit "should upload and download a big file" do
        chunks = 1024 * 1024
        cfile = Tempfile.new("content_big")
        chunks.times do |i|
          cfile.write("x" * 10)
        end
        cfile.flush

        @oid = azure.create(File.new(cfile, "r"), "big-one")

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
      it "should raise an exception", :vcr => true do
        expect {
          @oid = azure_public.create("foobar", "obecjt-id-1")
        }.to raise_error Bosh::Blobstore::BlobstoreError
      end
    end

    describe "Get object" do

      # VCR has issues with the HTTPClient from simple blobstore
      xit "should save to a file", :vcr => true do
        @oid = azure.create("content", "idA")
        file = Tempfile.new("contents")
        azure_public.get(@oid, file)
        file.rewind
        file.read.should eq content
      end

      # VCR has issues with the HTTPClient from simple blobstore
      xit "should return the contents", :vcr => true do
        @oid = azure.create(content, "idB")
        azure_public.get(@oid).should eq content
      end

      it "should raise an exception if the object id is invalid", :vcr => true do
        expect {
          azure_public.get("notpresent")
        }.to raise_error Bosh::Blobstore::BlobstoreError
      end

    end

    describe "Check object", :vcr => true do
      it "should check if the object exists" do
        @oid = azure.create(content, "idD")
        azure_public.exists?(@oid).should be_true
      end

      it "should check if the object does not exist", :vcr => true do
        azure_public.exists?("invalid-content-id").should be_false
      end
    end

    describe "Delete object", :vcr => true do
      it "should raise an exception" do
        @oid = azure.create(content, "idE")
        expect {
          azure_public.delete(@oid)
        }.to raise_error Bosh::Blobstore::BlobstoreError
      end

    end

  end

end
