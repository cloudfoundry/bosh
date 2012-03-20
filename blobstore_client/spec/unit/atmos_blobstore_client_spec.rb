require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Blobstore::AtmosBlobstoreClient do

  before(:each) do
    @atmos = mock("atmos")
    Atmos::Store.stub!(:new).and_return(@atmos)
    atmos_opt = {:url => "http://localhost",
                 :uid => "uid",
                 :secret => "secret"}

    @http_client = mock("http-client")
    ssl_opt = mock("ssl-opt")
    ssl_opt.stub!(:verify_mode=)
    @http_client.stub!(:ssl_config).and_return(ssl_opt)

    HTTPClient.stub!(:new).and_return(@http_client)
    @client = Bosh::Blobstore::AtmosBlobstoreClient.new(atmos_opt)
  end

  it "should create an object" do
    data = "some content"
    object = mock("object")

    @atmos.should_receive(:create).with {|opt|
      opt[:data].read.should eql data
      opt[:length].should eql data.length
    }.and_return(object)

    object.should_receive(:aoid).and_return("test-key")

    object_id = @client.create(data)
    object_info = MultiJson.decode(Base64.decode64(URI::unescape(object_id)))
    object_info["oid"].should eql("test-key")
    object_info["sig"].should_not be_nil
  end

  it "should delete an object" do
    object = mock("object")
    @atmos.should_receive(:get).with(:id => "test-key").and_return(object)
    object.should_receive(:delete)
    id = URI::escape(Base64.encode64(MultiJson.encode({:oid => "test-key", :sig => "sig"})))
    @client.delete(id)
  end

  it "should fetch an object" do
    url = "http://localhost/rest/objects/test-key?uid=uid&expires=1893484800&signature=sig"
    response = mock("response")
    response.stub!(:status).and_return(200)
    @http_client.should_receive(:get).with(url).and_yield("some-content").and_return(response)
    id = URI::escape(Base64.encode64(MultiJson.encode({:oid => "test-key", :sig => "sig"})))
    @client.get(id).should eql("some-content")
  end

  it "should refuse to create object without the password" do
    lambda {
      no_pass_client = Bosh::Blobstore::AtmosBlobstoreClient.new(:url => "http://localhost", :uid => "uid")
      no_pass_client.create("foo")
    }.should raise_error(Bosh::Blobstore::BlobstoreError)
  end

  it "should be able to read without password" do
    no_pass_client = Bosh::Blobstore::AtmosBlobstoreClient.new(:url => "http://localhost", :uid => "uid")

    url = "http://localhost/rest/objects/test-key?uid=uid&expires=1893484800&signature=sig"
    response = mock("response")
    response.stub!(:status).and_return(200)
    @http_client.should_receive(:get).with(url).and_yield("some-content").and_return(response)
    id = URI::escape(Base64.encode64(MultiJson.encode({:oid => "test-key", :sig => "sig"})))
    no_pass_client.get(id).should eql("some-content")
  end
end
