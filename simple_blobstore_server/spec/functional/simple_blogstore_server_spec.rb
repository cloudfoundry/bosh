require 'spec_helper'

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
      expect(last_response.status).to eq(404)
    end

    it "should reject invalid password" do
      get "/resources/foo" , {}, {"HTTP_AUTHORIZATION" => encode_credentials("john", "bad_password")}
      expect(last_response.status).to eq(401)
    end

    it "should reject invalid user" do
      get "/resources/foo" , {}, {"HTTP_AUTHORIZATION" => encode_credentials("bad_user", "doe")}
      expect(last_response.status).to eq(401)
    end

    it "should reject invalid user and password" do
      get "/resources/foo" , {}, {"HTTP_AUTHORIZATION" => encode_credentials("bad_user", "bad_password")}
      expect(last_response.status).to eq(401)
    end

    it "should reject unauthenticated users" do
      get "/resources/foo"
      expect(last_response.status).to eq(401)
    end

  end

  describe "Creating resources" do

    before(:each) do
      @resource_file = Tempfile.new("resource")
      @resource_file.write("test contents")
      @resource_file.close
    end

    after(:each) do
      @resource_file.delete
    end

    it "should create a token for a new resource" do
      post "/resources", {"content" => Rack::Test::UploadedFile.new(@resource_file.path, "plain/text") },
           {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
      expect(last_response.status).to eq(200)
      object_id = last_response.body

      get "/resources/#{object_id}", {}, {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq("test contents")
    end

    it 'should accept object id suggestion' do
      post "/resources/foobar", {"content" => Rack::Test::UploadedFile.new(@resource_file.path, "plain/text") },
           {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
      expect(last_response.status).to eq(200)
      object_id = last_response.body

      expect(object_id).to eq("foobar")

      get "/resources/#{object_id}", {}, {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq("test contents")
    end

    it 'should return a 409 error if the suggested id is taken' do
      post "/resources/foobar", {"content" => Rack::Test::UploadedFile.new(@resource_file.path, "plain/text") },
           {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
      expect(last_response.status).to eq(200)

      post "/resources/foobar", {"content" => Rack::Test::UploadedFile.new(@resource_file.path, "plain/text") },
           {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
      expect(last_response.status).to eq(409)
    end
  end

  describe "Fetching resources" do

    it "should return an error if the resource is not found" do
      get "/resources/foo" , {}, {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
      expect(last_response.status).to eq(404)
    end

    it "should set Nginx header when Nginx support is enabled" do
      config = {
        "path" => @path,
        "users" => {
          "john" => "doe"
        },
        "nginx_path" => "/protected"
      }
      @app = Bosh::Blobstore::SimpleBlobstoreServer.new(config)

      resource_file = Tempfile.new("resource")
      begin
        resource_file.write("test contents")
        resource_file.close
        post "/resources", {"content" => Rack::Test::UploadedFile.new(resource_file.path, "plain/text") },
             {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
        expect(last_response.status).to eq(200)
        object_id = last_response.body
        get "/resources/#{object_id}", {}, {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq("")
        expect(last_response.headers["X-Accel-Redirect"]).to eq(
            "/protected/#{Digest::SHA1.hexdigest(object_id)[0, 2]}/#{object_id}"
        )
      ensure
        resource_file.delete
      end
    end

  end

  describe 'checking if an object exists' do
    it 'should return 200 if it exists' do
      resource_file = Tempfile.new("resource")
      begin
        resource_file.write("test contents")
        resource_file.close
        post "/resources/foo", {"content" => Rack::Test::UploadedFile.new(resource_file.path, "plain/text") },
             {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
        expect(last_response.status).to eq(200)
      ensure
        resource_file.delete
      end

      head "/resources/foo", {}, {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
      expect(last_response.status).to eq(200)
    end

    it 'should return 404 if it does not exist' do
      head "/resources/foo", {}, {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
      expect(last_response.status).to eq(404)
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
        expect(last_response.status).to eq(200)
        object_id = last_response.body

        get "/resources/#{object_id}", {}, {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq("test contents")

        delete "/resources/#{object_id}", {}, {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
        expect(last_response.status).to eq(204)

        get "/resources/#{object_id}", {}, {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
        expect(last_response.status).to eq(404)
      ensure
        resource_file.delete
      end
    end

    it "should return an error if the resource is not found" do
      delete "/resources/foo" , {}, {"HTTP_AUTHORIZATION" => encode_credentials("john", "doe")}
      expect(last_response.status).to eq(404)
    end

  end

end