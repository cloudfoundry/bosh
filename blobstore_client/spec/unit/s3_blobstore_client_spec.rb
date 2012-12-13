require  'spec_helper'

describe Bosh::Blobstore::S3BlobstoreClient do

  def s3_blobstore(options)
    @s3 = double(AWS::S3)
    AWS::S3.stub(:new).and_return(@s3)
    Bosh::Blobstore::S3BlobstoreClient.new(options)
  end

  describe "options" do
    it "should support symbols as option keys" do
      options = {:bucket_name       => "test",
                 :access_key_id     => "KEY",
                 :secret_access_key => "SECRET"}

      s3_blobstore(options).bucket_name.should == "test"
    end

    it "should support strings as option keys" do
      options = {"bucket_name"       => "test",
                 "access_key_id"     => "KEY",
                 "secret_access_key" => "SECRET"}

      s3_blobstore(options).bucket_name.should == "test"
    end

    it "should raise an error if using simple and encryption" do
      options = {"bucket_name"       => "test",
                 "encryption_key"    => "KEY"}
      expect {
        s3_blobstore(options)
      }.to raise_error Bosh::Blobstore::BlobstoreError,
                       "can't use read-only with an encryption key"
    end
  end

  describe "create" do
    context "encrypted" do
      let(:options) {
        {
          :bucket_name       => "test",
          :access_key_id     => "KEY",
          :secret_access_key => "SECRET",
          :encryption_key => "kjahsdjahsgdlahs"
        }
      }
      let(:client) { s3_blobstore(options) }

      it "should encrypt" do
        client.should_receive(:store_in_s3) do |path, id|
          File.open(path).read.should_not == "foobar"
        end
        client.create("foobar")
      end
    end

    context "unencrypted" do
      let(:options) {
        {
          :bucket_name       => "test",
          :access_key_id     => "KEY",
          :secret_access_key => "SECRET"
        }
      }
      let(:client) { s3_blobstore(options) }

      it "should not encrypt when key is missing" do
        client.should_not_receive(:encrypt_file)
        client.should_receive(:store_in_s3)
        client.create("foobar")
      end

      it "should take a string as argument" do
        client.should_receive(:store_in_s3)
        client.create("foobar")
      end

      it "should take a file as argument" do
        client.should_receive(:store_in_s3)
        file = File.open(asset("file"))
        client.create(file)
      end
    end
  end

  describe "get" do
    let(:options) {
      {
        :bucket_name       => "test",
        :access_key_id     => "KEY",
        :secret_access_key => "SECRET"
      }
    }
    let(:client) { s3_blobstore(options) }

    it "should raise an error if the object is missing" do
      client.stub(:get_from_s3).and_raise AWS::S3::Errors::NoSuchKey.new(nil, nil)
      expect {
        client.get("missing-oid")
      }.to raise_error Bosh::Blobstore::BlobstoreError
    end

    context "encrypted" do
      let(:options) {
        {
          :bucket_name       => "test",
          :access_key_id     => "KEY",
          :secret_access_key => "SECRET",
          :encryption_key => "asdasdasd"
        }
      }

      it "should get an object" do
        pending "requires refactoring of get_file"
      end
    end

    context "unencrypted" do
      it "should get an object" do
        blob = double("blob")
        blob.should_receive(:read).and_yield("foooo")
        client.should_receive(:get_from_s3).and_return(blob)
        client.get("foooo").should == "foooo"
      end
    end
  end

  describe "delete" do
    it "should delete an object" do
      options = {
        :encryption_key    => "bla",
        :bucket_name       => "test",
        :access_key_id     => "KEY",
        :secret_access_key => "SECRET"
      }
      client = s3_blobstore(options)
      blob = double("blob", :exists? => true)

      client.should_receive(:get_from_s3).with("fake-oid").and_return(blob)
      blob.should_receive(:delete)
      client.delete("fake-oid")
    end

    it "should raise an error when the object is missing" do
      options = {
        :encryption_key    => "bla",
        :bucket_name       => "test",
        :access_key_id     => "KEY",
        :secret_access_key => "SECRET"
      }
      client = s3_blobstore(options)
      blob = double("blob", :exists? => false)

      client.should_receive(:get_from_s3).with("fake-oid").and_return(blob)
      expect {
        client.delete("fake-oid")
      }.to raise_error Bosh::Blobstore::BlobstoreError, "no such object: fake-oid"
    end
  end
end
