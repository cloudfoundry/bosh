require File.dirname(__FILE__) + '/../spec_helper'

require "base64"

describe Bosh::Blobstore::SimpleBlobstoreServer do
  include Rack::Test::Methods

  before(:each) do
    @path = Dir.mktmpdir("blobstore")
    config = {
      "path" => @path,
      "users" => {
        "john" => "doe"
      }
    }
    @app = Bosh::Blobstore::SimpleBlobstoreServer.new(config)
  end

  after(:each) do
    FileUtils.rm_rf(@path)
  end

  def app
    @app
  end

  def encode_credentials(username, password)
    "Basic " + Base64.encode64("#{username}:#{password}")
  end

  describe "Authentication" do

    it "should accept valid users" do
      get "/resources/foo" , {}, {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
      last_response.status.should eql(404)
    end

    it "should reject invalid users" do
      get "/resources/foo"
      last_response.status.should eql(401)
    end

  end

  describe "Creating resources" do

    it "should create a token for a new resource" do

      resource_file = Tempfile.new("resource")
      begin
        resource_file.write("test contents")
        resource_file.close
        post "/resources", {"content" => Rack::Test::UploadedFile.new(resource_file.path, "plain/text") },
             {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
        last_response.status.should eql(200)
        object_id = last_response.body

        get "/resources/#{object_id}", {}, {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
        last_response.status.should eql(200)
        last_response.body.should eql("test contents")
      ensure
        resource_file.delete
      end

    end

  end

  describe "Fetching resources" do

    it "should return an error if the resource is not found" do
      get "/resources/foo" , {}, {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
      last_response.status.should eql(404)
    end

  end

  describe "Deleting resources" do

    it "should delete an existing resource" do
      resource_file = Tempfile.new("resource")
      begin
        resource_file.write("test contents")
        resource_file.close
        post "/resources", {"content" => Rack::Test::UploadedFile.new(resource_file.path, "plain/text") },
             {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
        last_response.status.should eql(200)
        object_id = last_response.body

        get "/resources/#{object_id}", {}, {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
        last_response.status.should eql(200)
        last_response.body.should eql("test contents")

        delete "/resources/#{object_id}", {}, {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
        last_response.status.should eql(204)

        get "/resources/#{object_id}", {}, {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
        last_response.status.should eql(404)
      ensure
        resource_file.delete
      end
    end

    it "should return an error if the resource is not found" do
      delete "/resources/foo" , {}, {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
      last_response.status.should eql(404)
    end

  end

end