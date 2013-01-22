require 'spec_helper'
require 'tempfile'
require 'net/http'

describe Bosh::Blobstore::S3BlobstoreClient do
  EXISTING_BLOB_ID = "d704cb05d9c6af7e74188f4a858f33de"

  def access_key_id
    key = ENV['EC2_ACCESS_KEY']
    raise "need to set EC2_ACCESS_KEY" unless key
    key
  end

  def secret_access_key
    key = ENV['EC2_SECRET_KEY']
    raise "need to set EC2_SECRET_KEY" unless key
    key
  end

  context "Read/Write" do
    after(:each) do
      @s3.delete(@oid) if @oid
      @s3.delete(@oid2) if @oid2
    end

    before do
      pending "EC2_ACCESS_KEY required to run S3 specs" unless ENV['EC2_ACCESS_KEY']
      s3_options = {
          :bucket_name => "bosh-blobstore-bucket",
          :access_key_id => access_key_id,
          :secret_access_key => secret_access_key
      }
      @s3 = Bosh::Blobstore::Client.create("s3", s3_options)
    end

    describe "unencrypted" do
      describe "store object" do
        it "should upload a file" do
          Tempfile.new("foo") do |file|
            @oid = @s3.create(file)
            @oid.should_not be_nil
          end
        end

        it "should upload a string" do
          @oid = @s3.create("foobar")
          @oid.should_not be_nil
        end

        it "should handle uploading the same object twice" do
          @oid = @s3.create("foobar")
          @oid.should_not be_nil
          @oid2 = @s3.create("foobar")
          @oid2.should_not be_nil
          @oid.should_not == @oid2
        end
      end

      describe "get object" do
        it "should save to a file" do
          @oid = @s3.create("foobar")
          file = Tempfile.new("contents")
          @s3.get(@oid, file)
          file.rewind
          file.read.should == "foobar"
        end

        it "should return the contents" do
          @oid = @s3.create("foobar")
          @s3.get(@oid).should == "foobar"
        end

        it "should raise an error when the object is missing" do
          id = "foooooo"
          expect {
            @s3.get(id)
          }.to raise_error Bosh::Blobstore::BlobstoreError, "S3 object '#{id}' not found"
        end
      end

      describe "delete object" do
        it "should delete an object" do
          @oid = @s3.create("foobar")
          expect {
            @s3.delete(@oid)
          }.to_not raise_error
          @oid = nil
        end

        it "should raise an error when object doesn't exist" do
          expect {
            @s3.delete("foobar")
          }.to raise_error Bosh::Blobstore::BlobstoreError
        end
      end
    end

    context "encrypted", :focus => true do
      before do
        pending "EC2_ACCESS_KEY required to run S3 specs" unless ENV['EC2_ACCESS_KEY']
        s3_options = {
            :bucket_name => "bosh-blobstore-bucket",
            :access_key_id => access_key_id,
            :secret_access_key => secret_access_key,
            :encryption_key => "kjahsdjahsgdlahs"
        }
        @s3 = Bosh::Blobstore::Client.create("s3", s3_options)
      end

      describe "get object" do
        it "should be backwards compatible with blobstore_client 0.5.0 blobs" do
          oid = "c45a6478-fce0-4f74-b68c-f465111fe2f3"
          @s3.get(oid).should == "skadim vadar"
        end
      end

      describe "create object" do
        it "should be encrypted" do
          @oid = @s3.create("foobar")
          @s3.get(@oid).should == "foobar"
        end
      end
    end
  end

  context "Read-Only" do
    before(:all) do
      s3_options = {
          :endpoint => "https://s3-us-west-1.amazonaws.com",
          :bucket_name => "bosh-blobstore-bucket"
      }
      @s3 = Bosh::Blobstore::Client.create("s3", s3_options)
    end

    describe "get object" do
      it "should save to a file" do
        file = Tempfile.new("contents")
        @s3.get(EXISTING_BLOB_ID, file)
        file.rewind
        file.read.should == EXISTING_BLOB_ID
      end

      it "should return the contents" do
        @s3.get(EXISTING_BLOB_ID).should == EXISTING_BLOB_ID
      end

      it "should raise an error when the object is missing" do
        id = "foooooo"
        expect {
          @s3.get(id)
        }.to raise_error Bosh::Blobstore::BlobstoreError, /Could not fetch object/
      end
    end

    describe "create object" do
      it "should raise an error" do
        expect {
          @s3.create("foobar")
        }.to raise_error Bosh::Blobstore::BlobstoreError, "unsupported action"
      end
    end

    describe "delete object" do
      it "should raise an error" do
        expect {
          @s3.delete(EXISTING_BLOB_ID)
        }.to raise_error Bosh::Blobstore::BlobstoreError, "unsupported action"
      end
    end

  end
end
