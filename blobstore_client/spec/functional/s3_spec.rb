require 'spec_helper'
require 'tempfile'
require 'net/http'

describe Bosh::Blobstore::S3BlobstoreClient, :s3_credentials => true do
  EXISTING_BLOB_ID = "d704cb05d9c6af7e74188f4a858f33de"

  def access_key_id
    key = ENV['AWS_ACCESS_KEY_ID']
    raise "need to set AWS_ACCESS_KEY_ID environment variable" unless key
    key
  end

  def secret_access_key
    key = ENV['AWS_SECRET_ACCESS_KEY']
    raise "need to set AWS_SECRET_ACCESS_KEY environment variable" unless key
    key
  end

  def bucket_name
    key = ENV['S3_BUCKET_NAME']
    raise "need to set S3_BUCKET_NAME environment variable" unless key
    key
  end

  context "Read/Write" do
    let(:s3_options) do
      {
        :bucket_name => bucket_name,
        :access_key_id => access_key_id,
        :secret_access_key => secret_access_key,
      }
    end

    let(:s3) do
      Bosh::Blobstore::Client.create("s3", s3_options)
    end

    after(:each) do
      s3.delete(@oid) if @oid
      s3.delete(@oid2) if @oid2
    end

    describe "unencrypted" do
      describe "store object" do
        it "should upload a file" do
          Tempfile.new("foo") do |file|
            @oid = s3.create(file)
            @oid.should_not be_nil
          end
        end

        it "should upload a string" do
          @oid = s3.create("foobar")
          @oid.should_not be_nil
        end

        it "should handle uploading the same object twice" do
          @oid = s3.create("foobar")
          @oid.should_not be_nil
          @oid2 = s3.create("foobar")
          @oid2.should_not be_nil
          @oid.should_not == @oid2
        end
      end

      describe "get object" do
        it "should save to a file" do
          @oid = s3.create("foobar")
          file = Tempfile.new("contents")
          s3.get(@oid, file)
          file.rewind
          file.read.should == "foobar"
        end

        it "should return the contents" do
          @oid = s3.create("foobar")
          s3.get(@oid).should == "foobar"
        end

        it "should raise an error when the object is missing" do
          id = "foooooo"
          expect {
            s3.get(id)
          }.to raise_error Bosh::Blobstore::BlobstoreError, "S3 object '#{id}' not found"
        end
      end

      describe "delete object" do
        it "should delete an object" do
          @oid = s3.create("foobar")
          expect {
            s3.delete(@oid)
          }.to_not raise_error
          @oid = nil
        end

        it "should raise an error when object doesn't exist" do
          expect {
            s3.delete("foobar")
          }.to raise_error Bosh::Blobstore::BlobstoreError
        end
      end
    end

    context "encrypted" do
      let(:unencrypted_s3) do
        s3
      end

      let(:encrypted_s3) do
        Bosh::Blobstore::Client.create("s3", s3_options.merge(:encryption_key => "kjahsdjahsgdlahs"))
      end

      describe "backwards compatibility" do
        it "should work when a blob was uploaded by blobstore_client 0.5.0" do
          @oid = unencrypted_s3.create(File.read(asset("encrypted_blob_from_blobstore_client_0.5.0")))
          encrypted_s3.get(@oid).should == "skadim vadar"
        end
      end

      describe "create object" do
        it "should be encrypted" do
          @oid = encrypted_s3.create("foobar")
          encrypted_s3.get(@oid).should == "foobar"
        end
      end
    end
  end

  context "Read-Only" do
    let(:s3_options) do
      {
        :endpoint => "https://s3-us-west-1.amazonaws.com",
        :bucket_name => "bosh-blobstore-bucket"
      }
    end

    let(:s3) do
      Bosh::Blobstore::Client.create("s3", s3_options)
    end

    describe "get object" do
      it "should save to a file" do
        file = Tempfile.new("contents")
        s3.get(EXISTING_BLOB_ID, file)
        file.rewind
        file.read.should == EXISTING_BLOB_ID
      end

      it "should return the contents" do
        s3.get(EXISTING_BLOB_ID).should == EXISTING_BLOB_ID
      end

      it "should raise an error when the object is missing" do
        id = "foooooo"
        expect {
          s3.get(id)
        }.to raise_error Bosh::Blobstore::BlobstoreError, /Could not fetch object/
      end
    end

    describe "create object" do
      it "should raise an error" do
        expect {
          s3.create("foobar")
        }.to raise_error Bosh::Blobstore::BlobstoreError, "unsupported action"
      end
    end

    describe "delete object" do
      it "should raise an error" do
        expect {
          s3.delete(EXISTING_BLOB_ID)
        }.to raise_error Bosh::Blobstore::BlobstoreError, "unsupported action"
      end
    end
  end
end
