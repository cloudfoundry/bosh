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
    options = {:access_key_id => "foo", :secret_access_key => "bar"}
    bs = Bosh::Blobstore::Client.create('s3', options)
    bs.should be_instance_of Bosh::Blobstore::S3BlobstoreClient
  end

  it "should pick S3 provider when S3 is used without credentials" do
    bs = Bosh::Blobstore::Client.create('s3', {:bucket_name => "foo"})
    bs.should be_instance_of Bosh::Blobstore::S3BlobstoreClient
  end

  it "should raise an exception on an unknown client" do
    lambda {
      bs = Bosh::Blobstore::Client.create('foobar', {})
    }.should raise_error /^Invalid client provider/
  end

end
