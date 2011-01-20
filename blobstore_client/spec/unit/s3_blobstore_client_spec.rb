require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Blobstore::S3BlobstoreClient do

  before(:each) do
    @aws_mock_options = {
      :access_key_id     => "KEY",
      :secret_access_key => "SECRET"
    }
  end

  def s3_blobstore(options)
    Bosh::Blobstore::S3BlobstoreClient.new(options)
  end

  describe "options" do

    it "establishes S3 connection on creation" do
      AWS::S3::Base.should_receive(:establish_connection!).with(@aws_mock_options)

      @client = s3_blobstore("encryption_key"    => "bla",
                             "bucket_name"       => "test",
                             "access_key_id"     => "KEY",
                             "secret_access_key" => "SECRET")

      @client.encryption_key.should == "bla"
      @client.bucket_name.should == "test"
    end

    it "supports Symbol option keys too" do
      AWS::S3::Base.should_receive(:establish_connection!).with(@aws_mock_options)

      @client = s3_blobstore(:encryption_key    => "bla",
                             :bucket_name       => "test",
                             :access_key_id     => "KEY",
                             :secret_access_key => "SECRET")

      @client.encryption_key.should == "bla"
      @client.bucket_name.should == "test"      
    end

  end

  describe "operations" do

    before :each do
      @client = s3_blobstore(:encryption_key    => "bla",
                             :bucket_name       => "test",
                             :access_key_id     => "KEY",
                             :secret_access_key => "SECRET")
    end

    it "should create an object" do
      @client.should_receive(:generate_object_id).and_return("object_id")
      @client.should_receive(:encrypt).with("some content").and_return("ENCRYPTED")

      AWS::S3::S3Object.should_receive(:store).with("object_id", Base64.encode64("ENCRYPTED"), "test")
      @client.create("some content")
    end

    it "should raise an exception when there is an error creating an object" do
      AWS::S3::S3Object.should_receive(:store).and_raise(AWS::S3::S3Exception.new("Epic Fail"))
      lambda {
        @client.create("some content")        
      }.should raise_error(Bosh::Blobstore::BlobstoreError, "Failed to create object, S3 response error: Epic Fail")
    end

    it "should fetch an object" do
      mock_s3_object = mock("s3_object")
      mock_s3_object.stub!(:value).and_return(Base64.encode64("ENCRYPTED"))
      AWS::S3::S3Object.should_receive(:find).with("object_id", "test").and_return(mock_s3_object)
      @client.should_receive(:decrypt).with("ENCRYPTED").and_return("stuff")
      @client.get("object_id").should == "stuff"
    end

    it "should raise an exception when there is an error fetching an object" do
      AWS::S3::S3Object.should_receive(:find).with("object_id", "test").and_raise(AWS::S3::S3Exception.new("Epic Fail"))
      lambda {
        @client.get("object_id")
      }.should raise_error(Bosh::Blobstore::BlobstoreError, "Failed to find object `object_id', S3 response error: Epic Fail")
    end

    it "should raise more specific NotFound exception when object is not found" do
      AWS::S3::S3Object.should_receive(:find).with("object_id", "test").and_raise(AWS::S3::NoSuchKey.new("NO KEY", "test"))
      lambda {
        @client.get("object_id")
      }.should raise_error(Bosh::Blobstore::BlobstoreError, "S3 object `object_id' not found")
    end    

    it "should delete an object" do
      AWS::S3::S3Object.should_receive(:delete).with("object_id", "test")
      @client.delete("object_id")
    end

    it "should raise an exception when there is an error deleting an object" do
      AWS::S3::S3Object.should_receive(:delete).with("object_id", "test").and_raise(AWS::S3::S3Exception.new("Epic Fail"))
      lambda {
        @client.delete("object_id")        
      }.should raise_error(Bosh::Blobstore::BlobstoreError, "Failed to delete object `object_id', S3 response error: Epic Fail")
    end

    it "encrypt/decrypt works as long as key is the same" do
      encrypted = @client.send(:encrypt, "clear text")
      @client.send(:decrypt, encrypted).should == "clear text"

      encrypted.should_not == "clear text" # Sanity check

      # Check that we don't have padding issues for very small inputs
      encrypted = @client.send(:encrypt, "c")
      @client.send(:decrypt, encrypted).should == "c"
    end    

    it "should raise an exception if incorrect encryption key is used" do
      encrypted = @client.send(:encrypt, "clear text")

      client2 = s3_blobstore(:encryption_key    => "zzz",
                             :bucket_name       => "test",
                             :access_key_id     => "KEY",
                             :secret_access_key => "SECRET")

      lambda {
        client2.send(:decrypt, encrypted)
      }.should raise_error(Bosh::Blobstore::BlobstoreError, "Decryption error: bad decrypt")
    end

  end

end
