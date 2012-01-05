require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Blobstore::AtmosBlobstoreClient do

  before(:each) do
    @atmos = mock("atmos")
    Atmos::Store.stub!(:new).and_return(@atmos)
    atmos_opt = {:url => "http://localhost",
                 :uid => "uid",
                 :secret => "secret"}
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

    @client.create(data).should eql("test-key")
  end

  it "should delete an object" do
    object = mock("object")
    @atmos.should_receive(:get).with(:id => "test-key").and_return(object)
    object.should_receive(:delete)

    @client.delete("test-key")
  end

  it "should fetch an object" do
    object = mock("object")
    @atmos.should_receive(:get).with(:id => "test-key").and_return(object)
    object.should_receive(:data_as_stream).and_yield("some-content")

    @client.get("test-key").should eql("some-content")
  end
end
