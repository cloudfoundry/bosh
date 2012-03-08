require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Blobstore::Client do

  it "should have a local provider" do
    Dir.mktmpdir do |tmp|
      bs = Bosh::Blobstore::Client.create('local', {:blobstore_path => tmp})
      bs.should be_instance_of Bosh::Blobstore::LocalClient
    end
  end

  it "should have an simple provider" do
    bs = Bosh::Blobstore::Client.create('simple', {})
    bs.should be_instance_of Bosh::Blobstore::SimpleBlobstoreClient
  end

  it "should have an atmos provider" do
    bs = Bosh::Blobstore::Client.create('atmos', {})
    bs.should be_instance_of Bosh::Blobstore::AtmosBlobstoreClient
  end

  it "should have an s3 provider" do
    pending "can't create s3 client without credentials"
  #   bs = Bosh::Blobstore::Client.create('atmos', {})
  #   puts bs.class
  #   bs.should be_instance_of Bosh::Blobstore::S3BlobstoreClient
  end

  it "should raise an exception on an unknown client" do
    lambda {
      bs = Bosh::Blobstore::Client.create('foobar', {})
      }.should raise_error /^Invalid client provider/
  end
end
