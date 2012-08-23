require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Blobstore::SwiftBlobstoreClient do

  def swift_options(container_name, swift_provider, credentials)
    if credentials
      options = {
                  "rackspace" => {
                    "rackspace_username" => "username",
                    "rackspace_api_key" => "api_key"
                  },
                  "hp" => {
                    "hp_account_id" => "account_id",
                    "hp_secret_key" => "secret_key",
                    "hp_tenant_id"  => "tenant_id"
                  }
                }
    else
      options = {}
    end
    options["container_name"] = container_name if container_name
    options["swift_provider"] = swift_provider if swift_provider
    options
  end

  def swift_blobstore(options)
    Bosh::Blobstore::SwiftBlobstoreClient.new(options)
  end

  before(:each) do
    @swift = mock("swift")
    Fog::Storage.stub!(:new).and_return(@swift)
    @http_client = mock("http-client")
    HTTPClient.stub!(:new).and_return(@http_client)
  end

  describe "on HP Cloud Storage" do

    describe "with credentials" do

      before(:each) do
        @client = swift_blobstore(swift_options("test-container",
                                                "hp",
                                                true))
      end

      it "should create an object" do
        data = "some content"
        directories = double("directories")
        container = double("container")
        files = double("files")
        object = double("object")

        @client.should_receive(:generate_object_id).and_return("object_id")
        @swift.stub(:directories).and_return(directories)
        directories.should_receive(:get).with("test-container") \
                   .and_return(container)
        container.should_receive(:files).and_return(files)
        files.should_receive(:create).with { |opt|
          opt[:key].should eql "object_id"
          #opt[:body].should eql data
          opt[:public].should eql true
        }.and_return(object)
        object.should_receive(:public_url).and_return("public-url")

        object_id = @client.create(data)
        object_info = MultiJson.decode(Base64.decode64(
                                         URI::unescape(object_id)))
        object_info["oid"].should eql("object_id")
        object_info["purl"].should eql("public-url")
      end

      it "should fetch an object without a public url" do
        data = "some content"
        directories = double("directories")
        container = double("container")
        files = double("files")
        object = double("object")

        @swift.stub(:directories).and_return(directories)
        directories.should_receive(:get).with("test-container") \
                   .and_return(container)
        container.should_receive(:files).and_return(files)
        files.should_receive(:get).with("object_id").and_yield(data) \
             .and_return(object)

        oid = URI::escape(Base64.encode64(MultiJson.encode(
                                            {:oid => "object_id"})))
        @client.get(oid).should eql(data)
      end

      it "should fetch an object with a public url" do
        data = "some content"
        response = mock("response")

        @http_client.should_receive(:get).with("public-url") \
                    .and_yield(data).and_return(response)
        response.stub!(:status).and_return(200)

        oid = URI::escape(Base64.encode64(MultiJson.encode(
                                            {:oid => "object_id",
                                             :purl => "public-url"})))
        @client.get(oid).should eql(data)
      end

      it "should delete an object" do
        directories = double("directories")
        container = double("container")
        files = double("files")
        object = double("object")

        @swift.stub(:directories).and_return(directories)
        directories.should_receive(:get).with("test-container") \
                   .and_return(container)
        container.should_receive(:files).and_return(files)
        files.should_receive(:get).with("object_id").and_return(object)
        object.should_receive(:destroy)

        oid = URI::escape(Base64.encode64(MultiJson.encode(
                                            {:oid => "object_id"})))
        @client.delete(oid)
      end

    end

    describe "without credentials" do

      before(:each) do
        @client = swift_blobstore(swift_options("test-container",
                                                "hp",
                                                false))
      end

      it "should refuse to create an object" do
        data = "some content"

        lambda {
          object_id = @client.create(data)
        }.should raise_error(Bosh::Blobstore::BlobstoreError)
      end

      it "should refuse to fetch an object without a public url" do
        oid = URI::escape(Base64.encode64(MultiJson.encode(
                                            {:oid => "object_id"})))
        lambda {
          @client.get(oid)
        }.should raise_error(Bosh::Blobstore::BlobstoreError)
      end

      it "should fetch an object with a public url" do
        data = "some content"
        response = mock("response")

        @http_client.should_receive(:get).with("public-url") \
                    .and_yield(data).and_return(response)
        response.stub!(:status).and_return(200)

        oid = URI::escape(Base64.encode64(MultiJson.encode(
                                            {:oid => "object_id",
                                             :purl => "public-url"})))
        @client.get(oid).should eql(data)
      end

      it "should refuse to delete an object" do
        oid = URI::escape(Base64.encode64(MultiJson.encode(
                                            {:oid => "object_id"})))
        lambda {
          @client.delete(oid)
        }.should raise_error(Bosh::Blobstore::BlobstoreError)
      end

    end

  end

  describe "on Rackspace Cloud Files" do

    describe "with credentials" do

      before(:each) do
        @client = swift_blobstore(swift_options("test-container",
                                                "rackspace",
                                                true))
      end

      it "should create an object" do
        data = "some content"
        directories = double("directories")
        container = double("container")
        files = double("files")
        object = double("object")

        @client.should_receive(:generate_object_id).and_return("object_id")
        @swift.stub(:directories).and_return(directories)
        directories.should_receive(:get).with("test-container") \
                   .and_return(container)
        container.should_receive(:files).and_return(files)
        files.should_receive(:create).with { |opt|
          opt[:key].should eql "object_id"
          #opt[:body].should eql data
          opt[:public].should eql true
        }.and_return(object)
        object.should_receive(:public_url).and_return("public-url")

        object_id = @client.create(data)
        object_info = MultiJson.decode(Base64.decode64(
                                         URI::unescape(object_id)))
        object_info["oid"].should eql("object_id")
        object_info["purl"].should eql("public-url")
      end

      it "should fetch an object without a public url" do
        data = "some content"
        directories = double("directories")
        container = double("container")
        files = double("files")
        object = double("object")

        @swift.stub(:directories).and_return(directories)
        directories.should_receive(:get).with("test-container") \
                   .and_return(container)
        container.should_receive(:files).and_return(files)
        files.should_receive(:get).with("object_id").and_yield(data) \
             .and_return(object)

        oid = URI::escape(Base64.encode64(MultiJson.encode(
                                            {:oid => "object_id"})))
        @client.get(oid).should eql(data)
      end

      it "should fetch an object with a public url" do
        data = "some content"
        response = mock("response")

        @http_client.should_receive(:get).with("public-url") \
                    .and_yield(data).and_return(response)
        response.stub!(:status).and_return(200)

        oid = URI::escape(Base64.encode64(MultiJson.encode(
                                            {:oid => "object_id",
                                             :purl => "public-url"})))
        @client.get(oid).should eql(data)
      end

      it "should delete an object" do
        directories = double("directories")
        container = double("container")
        files = double("files")
        object = double("object")

        @swift.stub(:directories).and_return(directories)
        directories.should_receive(:get).with("test-container") \
                   .and_return(container)
        container.should_receive(:files).and_return(files)
        files.should_receive(:get).with("object_id").and_return(object)
        object.should_receive(:destroy)

        oid = URI::escape(Base64.encode64(MultiJson.encode(
                                            {:oid => "object_id"})))
        @client.delete(oid)
      end

    end

    describe "without credentials" do

      before(:each) do
        @client = swift_blobstore(swift_options("test-container",
                                                "rackspace",
                                                false))
      end

      it "should refuse to create an object" do
        data = "some content"

        lambda {
          object_id = @client.create(data)
        }.should raise_error(Bosh::Blobstore::BlobstoreError)
      end

      it "should refuse to fetch an object without a public url" do
        oid = URI::escape(Base64.encode64(MultiJson.encode(
                                            {:oid => "object_id"})))
        lambda {
          @client.get(oid)
        }.should raise_error(Bosh::Blobstore::BlobstoreError)
      end

      it "should fetch an object with a public url" do
        data = "some content"
        response = mock("response")

        @http_client.should_receive(:get).with("public-url") \
                    .and_yield(data).and_return(response)
        response.stub!(:status).and_return(200)

        oid = URI::escape(Base64.encode64(MultiJson.encode(
                                            {:oid => "object_id",
                                             :purl => "public-url"})))
        @client.get(oid).should eql(data)
      end

      it "should refuse to delete an object" do
        oid = URI::escape(Base64.encode64(MultiJson.encode(
                                            {:oid => "object_id"})))
        lambda {
          @client.delete(oid)
        }.should raise_error(Bosh::Blobstore::BlobstoreError)
      end

    end

  end

end
