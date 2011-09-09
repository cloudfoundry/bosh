require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::ResourceManager do

  before(:each) do
    @manager = Bosh::Director::ResourceManager.new
    @blobstore_dir = File.join(Dir.tmpdir, "blobstore")
    FileUtils.mkdir(@blobstore_dir)
    @blobstore = Bosh::Blobstore::Client.create("local", "blobstore_path" => @blobstore_dir)
    Bosh::Director::Config.stub!(:blobstore).and_return(@blobstore)
  end

  after(:each) do
    FileUtils.rm_rf(@blobstore_dir)
  end

  it "raises an error when trying to get non-existing resource" do
    lambda {
      @manager.get_resource("deadbeef")
    }.should raise_error(Bosh::Director::ResourceNotFound, "Resource deadbeef not found")
  end

  it "raises an error when something went wrong with blobstore" do
    @blobstore.stub!(:get).and_raise(Bosh::Blobstore::BlobstoreError.new("bad stuff"))
    lambda {
      @manager.get_resource("deadbeef")
    }.should raise_error(Bosh::Director::ResourceError, "Error fetching resource deadbeef: bad stuff")
  end

  it "saves resource to a local file" do
    id = @blobstore.create("some data")
    path = @manager.get_resource(id)
    File.exists?(path).should be_true
    File.read(path).should == "some data"
  end

end
