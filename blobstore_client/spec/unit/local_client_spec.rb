require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Blobstore::LocalClient do

  before(:each) do
    @tmp = Dir.mktmpdir
    @options = {"blobstore_path" => @tmp}
  end

  after(:each) do
    FileUtils.rm_rf(@tmp)
  end

  it "should require blobstore_path option" do
    lambda {
      client = Bosh::Blobstore::LocalClient.new({})
    }.should raise_error
  end

  it "should create blobstore_path direcory if it doesn't exist'" do
    dir = File.join(@tmp, "blobstore")
    client = Bosh::Blobstore::LocalClient.new({"blobstore_path" => dir})
    File.directory?(dir).should be_true
  end

  describe "operations" do

    describe "get" do
      it "should retrive the correct contents" do
        File.open(File.join(@tmp, 'foo'), 'w') do |fh|
          fh.puts("bar")
        end

        client = Bosh::Blobstore::LocalClient.new(@options)
        client.get("foo").should == "bar\n"
      end
    end

    describe "create" do
      it "should store a file" do
        test_file = File.join(File.dirname(__FILE__), "../assets/file")
        client = Bosh::Blobstore::LocalClient.new(@options)
        fh = File.open(test_file)
        id = client.create(fh)
        fh.close
        original = File.new(test_file).readlines
        stored = File.new(File.join(@tmp, id)).readlines
        stored.should == original
      end

      it "should store a string" do
        client = Bosh::Blobstore::LocalClient.new(@options)
        string = "foobar"
        id = client.create(string)
        stored = File.new(File.join(@tmp, id)).readlines
        stored.should == [string]
      end
    end

    describe "delete" do
      it "should delete an id" do
        client = Bosh::Blobstore::LocalClient.new(@options)
        string = "foobar"
        id = client.create(string)
        client.delete(id)
        File.exist?(File.join(@tmp, id)).should_not be_true
      end

      it "should raise NotFound error when trying to delete a missing id" do
        client = Bosh::Blobstore::LocalClient.new(@options)
        lambda {
          client.delete("missing")
          }.should raise_error Bosh::Blobstore::NotFound
      end
    end

  end
end
